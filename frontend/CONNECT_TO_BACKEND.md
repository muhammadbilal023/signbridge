# Connect the app to the backend
1. Copy `lib/` and `pubspec.yaml` from this zip into your `Frontend` folder (replace). Run `flutter pub get`.
2. Start the backend:  cd backend ; .venv\Scripts\activate ; uvicorn app.main:app --reload   (check http://localhost:8000/docs)
3. Start the app:      flutter run -d chrome
Android emulator uses http://10.0.2.2:8000 automatically. Real phone: start the backend with --host 0.0.0.0 and run
   flutter run --dart-define=API_URL=http://<your-PC-IP>:8000
Android also needs <uses-permission android:name="android.permission.INTERNET"/> and android:usesCleartextTraffic="true" on <application> in android/app/src/main/AndroidManifest.xml while you use plain http.
Connected: login, register, auto-login, profile, language, logout, history, text to sign. Still mock: sign to text camera, live session.
