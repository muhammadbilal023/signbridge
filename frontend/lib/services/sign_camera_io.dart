// Android / desktop / iOS implementation using flutter_webrtc.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'sign_camera.dart';

class SignCameraNative extends SignCamera {
  RTCVideoRenderer? _renderer;
  MediaStream? _stream;

  @override
  Future<void> start() async {
    _renderer = RTCVideoRenderer();
    await _renderer!.initialize();
    _stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}},
    });
    _renderer!.srcObject = _stream;
  }

  @override
  Future<Uint8List?> capture() async {
    final tracks = _stream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return null;
    final buf = await tracks.first.captureFrame();
    return buf.asUint8List();
  }

  @override
  Widget buildView({required bool mirror}) => RTCVideoView(
        _renderer!,
        mirror: mirror,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );

  @override
  Future<void> stop() async {
    _renderer?.srcObject = null;
    for (final t in _stream?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    _stream = null;
    try {
      await _renderer?.dispose();
    } catch (_) {}
    _renderer = null;
  }
}

SignCamera createSignCamera() => SignCameraNative();
