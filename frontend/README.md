# SignBridge app (Flutter, Web + Android)

## 1. Put the files in place
If `Frontend` already has your Flutter project (android/, web/ folders): just copy `lib/` and `pubspec.yaml` over it.
If not: inside this folder run `flutter create --platforms=web,android .` first, then copy `lib/` and `pubspec.yaml` over (replace).
Then:  `flutter pub get`

## 2. Start the backend, then the app
```
cd ..\backend
.venv\Scripts\activate
python -m uvicorn app.main:app --reload
```
New terminal:  `flutter run -d chrome`
(Without Firebase the app uses the backend's own email/password login, so you can try everything right away.)

## 3. Firebase: Google login + email verification link (recommended)
1. https://console.firebase.google.com -> Add project -> Authentication -> Get started -> turn on **Email/Password** and **Google**.
2. Install the tools once:  `npm i -g firebase-tools`  then  `dart pub global activate flutterfire_cli`  then  `firebase login`
3. In this folder:  `flutterfire configure --platforms=web,android`  (pick your project). It replaces `lib/firebase_options.dart`.
4. Backend `.env`:  `FIREBASE_PROJECT_ID=<your project id>`  and restart the backend.
5. Android + Google sign-in only: run `cd android` then `gradlew signingReport`, copy the **SHA-1** and **SHA-256** into Firebase -> Project settings -> your Android app, then run `flutterfire configure` again.
After this the login screen shows "Continue with Google", sign-up sends a verification email, and sign-in is refused until the link is opened.

## 4. Android settings (only when you run on an Android emulator/phone)
`android/app/src/main/AndroidManifest.xml` - add inside `<manifest>` (before `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<queries>
  <intent><action android:name="android.speech.RecognitionService"/></intent>
  <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
</queries>
```
and on the `<application ...>` tag add  `android:usesCleartextTraffic="true"`  (plain http while developing).
`android/app/build.gradle` (or `.kts`): set `minSdk = 23`.
Emulator reaches your PC at 10.0.2.2 automatically. Real phone: start the backend with `--host 0.0.0.0` and run
`flutter run --dart-define=API_URL=http://<your-PC-IP>:8000`

## 5. What works
Login / register / Google / email verification, profile (name, language, role), history, text -> sign playlist, **speech -> text** (mic on Text to Sign), **text -> speech** (Speak on Sign to Text), **real camera** with hand skeleton overlay, **live video call** with captions and chat (two browsers or two phones).

## 6. Honest limits
- Sign recognition is in **demo mode** until you add `models/word_model.onnx` + `labels.json` to the backend: the camera and hand tracking are real, the recognised words are placeholders.
- The camera sends about 5 pictures per second (works everywhere, but is not smooth video). Camera hand tracking needs the backend's ML packages (see backend README).
- Browser speech recognition works best in Chrome. Urdu speech/voice depends on the voices installed on the device.
- Video calls between different networks may need a TURN server; same Wi-Fi works with the free Google STUN server used here.
- Calls: the emotion badge and sign translation inside the call are not included yet.
- Sign video clips: add them with the admin account (`POST /vocabulary/{id}/clips`), otherwise Text to Sign shows the matched word without a video.
