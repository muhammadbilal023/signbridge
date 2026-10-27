# SignBridge

Real-time sign-language bridge: sign → text/speech, text → sign animation, and live sign-language video calls between two devices.

```
SignBridge/
  backend/    FastAPI server: auth, vocabulary, translation, WebSocket sign recognition, Socket.IO WebRTC signalling
  frontend/   Flutter app (Android + web): auth, Sign-to-Text, Text-to-Sign, live sessions
  start-dev.bat   starts backend + web frontend on Windows
```

## Quick start (local)
1. Backend: `cd backend`, create a venv, `pip install -r requirements.txt -r requirements-ml.txt`, copy `.env.example` to `.env`, then `uvicorn app.main:app --reload --port 8000`.
2. Frontend: `cd frontend`, `flutter pub get`, then `flutter run -d chrome` (web) or a connected Android device.
   For a physical Android device on your LAN: `flutter run --dart-define=API_URL=http://<laptop-ip>:8000`.

## Authentication
Firebase Auth (email/password + Google) is configured via `flutterfire configure`; the backend verifies Firebase ID tokens at `/auth/firebase` when `FIREBASE_PROJECT_ID` is set in `backend/.env`.
Google sign-in on Android requires the debug SHA-1 fingerprint registered in the Firebase Console (Project settings → Your apps → Android app).

## Live calls
WebRTC with STUN + a public TURN relay; signalling rides the backend Socket.IO server at `/socket.io`.

## Notes
The trained sign-recognition model is NOT included: the backend runs in demo mode until you add `backend/models/word_model.onnx` + `labels.json`.
