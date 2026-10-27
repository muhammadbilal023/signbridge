# SignBridge Backend (FastAPI)

Auth, vocabulary, text-to-sign, live sign recognition, sentence builder (LLM), live sessions (WebRTC signaling, captions, chat, emotion badge), history.
Implements the design in the diagrams (architecture 6, class 7, sequence 8-12, ERD 18).

## What is real and what is demo
| Part | Status |
|---|---|
| Auth: Firebase (Google + email with verification link) or plain email/password, JWT sessions, users, history, vocabulary, live sessions, chat, captions, Socket.IO signaling | **Real and tested** (34 automated tests) |
| Camera frames -> hand landmarks (`/ws/sign` with JPEG frames) | **Real**, needs `pip install mediapipe opencv-python-headless` (Python 3.12 or older). The hand model file downloads automatically on first start |
| Text-to-sign (phrase matching, English + Urdu) | **Real.** Returns a clip URL only for words that have an uploaded video clip |
| `/ws/sign` live recognition | **Real pipeline** (segmenting, normalizing, ONNX inference, threshold, sentence). Until you add `models/word_model.onnx` + `models/labels.json` it runs in **demo mode** (fake words) and says `"mode":"demo"` |
| Sentence builder | Real. Works with any OpenAI-compatible API (Grok, Qwen, Groq...). Without keys it safely returns the words joined |
| Speech-to-text (Whisper), text-to-speech (MMS), JPEG-frame landmarks, emotion | Code ready but **optional**: needs `requirements-ml.txt` and a flag. Emotion needs your trained `models/emotion.onnx`, else demo |

Nothing here is trained for you: **recognition accuracy depends entirely on the model you train in Colab.**

## Firebase login (Google + e-mail verification)
1. https://console.firebase.google.com -> Add project -> Build -> Authentication -> Get started -> enable **Email/Password** and **Google**.
2. Project settings -> copy the **Project ID** into `.env`: `FIREBASE_PROJECT_ID=your-project-id`, then restart the backend.
3. In the Flutter app folder run `flutterfire configure` (see the app README).
How it works: the app signs in with Firebase, then sends the Firebase ID token to `POST /auth/firebase`. The backend checks the token with Google's public keys and **only accepts verified e-mails**, so nobody can sign up with someone else's Gmail. With `FIREBASE_PROJECT_ID` set, the plain `/auth/register` and `/auth/login` are switched off (set `ALLOW_LOCAL_AUTH=true` to keep them). With it empty, the old email/password login works (no verification) - handy for quick tests.

## Run
```bash
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate   (Python 3.11 or 3.12 recommended)
python -m pip install -r requirements-dev.txt          # core only. Later: requirements-ml.txt (needs Python <= 3.12), requirements-postgres.txt
cp .env.example .env                                   # edit SECRET_KEY, LLM_*, ADMIN_*
uvicorn app.main:app --reload                          # http://localhost:8000/docs
pytest                                                 # all tests
```
Docker + PostgreSQL: `docker compose up --build` (set `INSTALL_ML: "true"` in the compose file for the ML extras).
Test the live pipeline without a frontend: `python tools/client_demo.py http://localhost:8000 me@example.com password123`.
Test the real ONNX path without training: `python tools/make_dummy_onnx.py models` (random model, same input/output shape).

## REST API (all JSON; send `Authorization: Bearer <token>` except where noted)
| Method + path | What it does |
|---|---|
| `GET /auth/config` | tells the app whether Firebase login is on |
| `POST /auth/firebase` `{id_token, role?, full_name?}` | exchange a Firebase ID token for the app token (verified e-mails only) |
| `POST /auth/register` `{full_name,email,password,role: deaf_mute\|hearing,preferred_language}` | create account (only when Firebase is off or `ALLOW_LOCAL_AUTH=true`) |
| `POST /auth/login` `{email,password}` | returns token + user |
| `GET/PATCH /users/me` | profile |
| `GET /vocabulary?q=&category=` (public) | sign words + clip URLs |
| `POST /vocabulary`, `POST /vocabulary/{id}/clips` (admin) | add word / upload mp4, webm, mov clip (max `MAX_UPLOAD_MB`) |
| `POST /text-to-sign` `{text}` | playlist `[{word, known, clip_url}]`; saved to history |
| `POST /sentence` `{words:[...], language}` | words to sentence (`source: llm\|fallback`) |
| `POST /stt` (multipart `file`, `language`) | speech to text (needs `ENABLE_STT`) |
| `POST /tts` `{text, language}` | returns `audio/wav` (needs `ENABLE_TTS`) |
| `POST /emotion` (multipart image) | one-shot emotion |
| `GET /recognition/status` (public) | `mode` (model/demo), labels, threshold, which features are on |
| `POST /sessions`, `POST /sessions/join {code}`, `GET /sessions`, `GET /sessions/{code}`, `POST /sessions/{code}/end` | one-to-one live sessions (code like `SB-123456`) |
| `GET /sessions/{code}/captions`, `/chat` | stored captions / chat |
| `GET /history?mode=&limit=&offset=`, `DELETE /history/{id}`, `DELETE /history` | translation history |

Only `deaf_mute` and `hearing` can self-register. The first admin comes from `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

## `/ws/sign?token=<JWT>&lang=en|ur`
Client to server:
- `{"type":"landmarks","data":[126 numbers],"t":<ms, optional>}` once per camera frame: left hand 21x(x,y,z), then right hand 21x(x,y,z). **All zeros = no hand.**
- binary JPEG frame (server extracts landmarks; needs `requirements-ml.txt`)
- `{"type":"finish"}` end the sentence now, `{"type":"reset"}` forget the current words

Server to client: `ready` (mode, threshold) | `word` (word, confidence, index) | `uncertain` (best, confidence) | `sentence` (words, sentence, source, history_id) | `error` (message).

How it works: frames with a hand are collected; a pause of `WORD_GAP_SECONDS` (0.5 s) closes one word, the word is classified; a pause of `SENTENCE_GAP_SECONDS` (1.5 s) after at least one word builds the sentence. Same flow as sequence diagram 9.
JPEG frames: the app sends about 5 pictures per second. The server also answers each one with `{"type":"hands","present":true,"points":[126 numbers]}` so the app can draw the hand skeleton on the camera preview.
Sending landmarks from the client (MediaPipe in the browser) is lighter and more private than sending video; JPEG frames are the simple option that works on web and Android.
**Training note:** the newest MediaPipe removed the old `mp.solutions` API that the Colab guide used. In Colab run `pip install mediapipe==0.10.14` (keeps the old API), or use the Tasks API like `app/services/landmarks.py`.

## Socket.IO (`/socket.io`, connect with `auth: {token: JWT}`)
First create/join the session over REST, then emit `join_room {code}`.
Relayed to the other person: `offer`, `answer`, `ice_candidate`, `translated_text {text,language}`, `emotion_update {label,confidence}`.
To both: `caption {text,language}`, `chat_message {body}`, `audio_chunk {audio:bytes,language}` (server transcribes then emits `caption`).
Server events: `peer_joined`, `peer_left`, `session_ended`. `end_session` closes the session. Each emit returns an ack `{ok, error?}`.

## Model contract (what your Colab notebook must export)
`models/word_model.onnx`: input `(1, 48, 130)` float32, output `(1, N)` raw logits. `models/labels.json`: list of N words in class-index order (a class called `none` is ignored).
Features must be exactly `app/services/features.py` (hands only: 2x21x3 landmarks, wrist at origin, scaled by hand size, plus 4 wrist x/y values, resampled to 48 frames). Use the same code in Colab when training.
```python
torch.onnx.export(model.cpu().eval(), torch.randn(1, 48, 130), "word_model.onnx",
                  input_names=["x"], output_names=["logits"], opset_version=17)
json.dump(labels, open("labels.json", "w"), ensure_ascii=False)
```
Emotion: `models/emotion.onnx`, input `(1,1,48,48)` in [0,1], 7 classes in FER2013 order (angry, disgust, fear, happy, sad, surprise, neutral).

## Configuration (`.env`)
See `.env.example`. Important: `DATABASE_URL`, `SECRET_KEY`, `CORS_ORIGINS`, `LLM_BASE_URL/API_KEY/MODEL`, `SIGN_THRESHOLD`, `ENABLE_STT/TTS`.

## Before you deploy
- `ENV=prod` and a long random `SECRET_KEY` (the app refuses the default in prod). Set `CORS_ORIGINS` to your real frontend URLs.
- Use HTTPS/WSS, and a STUN/TURN server for WebRTC (calls through strict networks fail without TURN).
- Replace `create_all` with Alembic migrations once the schema stabilises. Add rate limiting (e.g. a reverse proxy) on `/auth/*`.
- Tokens are sent in the WebSocket query string for simplicity; behind HTTPS this is acceptable for a prototype, but avoid logging full URLs.
- Never commit `.env`, and check each dataset/model licence (MMS TTS is non-commercial).

## Layout
`app/main.py` (app + Socket.IO), `routers/` (REST + websockets), `services/` (recognizer, features, segmenter, sentence, text-to-sign, stt, tts, emotion), `realtime.py` (Socket.IO), `models.py` (ERD tables), `tests/`, `tools/`.
