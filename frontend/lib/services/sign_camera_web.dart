// Web implementation using dart:html (getUserMedia + canvas.toDataUrl).
// Only compiled for web builds (see the conditional import in sign_camera.dart).
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import 'sign_camera.dart';

class SignCameraWeb extends SignCamera {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  html.CanvasElement? _canvas;
  String _viewTypeId = '';

  @override
  Future<void> start() async {
    final constraints = <String, Object>{
      'video': {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}},
      'audio': false,
    };
    _stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
    _video = html.VideoElement()
      ..srcObject = _stream
      ..muted = true
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..attributes['playsinline'] = 'true';
    await _video!.onLoadedMetadata.first;
    _canvas = html.CanvasElement(width: _video!.videoWidth, height: _video!.videoHeight);
    _viewTypeId = 'signbridge-camera-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewTypeId, (int viewId) => _video!);
  }

  @override
  Future<Uint8List?> capture() async {
    final vid = _video;
    final ctx = _canvas?.context2D;
    if (vid == null || ctx == null || vid.readyState < 2) return null;
    ctx.drawImage(vid, 0, 0);
    final dataUrl = _canvas!.toDataUrl('image/jpeg', 0.7);
    return base64Decode(dataUrl.split(',').last);
  }

  @override
  Widget buildView({required bool mirror}) =>
      Transform.scale(scaleX: mirror ? -1 : 1, child: HtmlElementView(viewType: _viewTypeId));

  @override
  Future<void> stop() async {
    _video?.srcObject = null;
    _video = null;
    _canvas = null;
    for (final t in _stream?.getVideoTracks() ?? <html.MediaStreamTrack>[]) {
      t.stop();
    }
    _stream = null;
  }
}

SignCamera createSignCamera() => SignCameraWeb();
