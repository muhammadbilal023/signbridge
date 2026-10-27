// Cross-platform camera for the Sign -> Text screen.
// Web uses dart:html (getUserMedia + canvas.toDataUrl); Android/desktop use
// flutter_webrtc (RTCVideoRenderer + MediaStreamTrack.captureFrame).
// The right implementation is picked at compile time by the conditional import below.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'sign_camera_stub.dart'
    if (dart.library.io) 'sign_camera_io.dart'
    if (dart.library.js_interop) 'sign_camera_web.dart' as impl;

SignCamera createSignCamera() => impl.createSignCamera();

abstract class SignCamera {
  /// Opens the camera and starts the preview. Throws if permission is denied.
  Future<void> start();

  /// Grabs the current frame as JPEG bytes, or null if not ready yet.
  Future<Uint8List?> capture();

  /// The live preview widget (already mirrored/unmirrored per [mirror]).
  Widget buildView({required bool mirror});

  /// Stops tracks and releases resources.
  Future<void> stop();
}
