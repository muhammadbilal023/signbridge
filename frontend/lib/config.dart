/// Runtime switches. Filled in at start-up (see main.dart and Api.loadConfig).
class AppConfig {
  static bool firebaseReady = false;   // Firebase initialised in this app (flutterfire configure was run)
  static bool backendFirebase = false; // the backend has FIREBASE_PROJECT_ID set
}
