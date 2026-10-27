import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:speech_to_text/speech_to_text.dart';

import '../services/api.dart';
import '../ui.dart';

const _red = Color(0xFFC0392B);
const _stage = Color(0xFF0D1830);

// ======================================================================= lobby
class LiveLobbyScreen extends StatefulWidget {
  const LiveLobbyScreen({super.key});
  @override
  State<LiveLobbyScreen> createState() => _LiveLobbyScreenState();
}

class _LiveLobbyScreenState extends State<LiveLobbyScreen> {
  final _join = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  Future<void> _go(Future<String> Function() getCode, bool host) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await getCode();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveCallScreen(code: code, isHost: host)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 560,
            child: LenisScroll(
              builder: (ctx, ctrl, physics) => ListView(
                controller: ctrl,
                physics: physics,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const TopBar(title: 'Live Session'),
                  FadeIn(
                    child: BorderBeam(
                      radius: 28,
                      child: Glass(
                        radius: 28,
                        padding: const EdgeInsets.all(24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Pill(text: 'New session', icon: Icons.video_call_rounded, hi: true),
                          const SizedBox(height: 14),
                          Text('Start a video call', style: h(24)),
                          const SizedBox(height: 6),
                          Text('You get a session code. Share it with the other person and they can join from their phone or browser.', style: b(14)),
                          const SizedBox(height: 18),
                          GlowButton(label: _busy ? 'Please wait...' : 'Start session', icon: Icons.video_call_rounded, onTap: _busy ? null : () => _go(Api.I.createSession, true)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    delay: 150,
                    child: Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Join with a code', style: h(18)),
                        const SizedBox(height: 14),
                        TextField(
                            controller: _join,
                            textCapitalization: TextCapitalization.characters,
                            style: b(16, color: C.text, w: FontWeight.w700),
                            decoration: const InputDecoration(labelText: 'Session code', hintText: 'SB-123456', prefixIcon: Icon(Icons.tag_rounded))),
                        const SizedBox(height: 14),
                        GlowButton(
                            label: 'Join session',
                            secondary: true,
                            onTap: _busy
                                ? null
                                : () {
                                    if (_join.text.trim().length < 3) {
                                      setState(() => _error = 'Type the session code first.');
                                      return;
                                    }
                                    _go(() => Api.I.joinSession(_join.text), false);
                                  }),
                      ]),
                    ),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, textAlign: TextAlign.center, style: b(13, color: _red, w: FontWeight.w600))),
                ],
              ),
            ),
          ),
        ),
      );
}

// ======================================================================= call
class _Msg {
  final bool mine;
  final String text;
  _Msg(this.mine, this.text);
}

class LiveCallScreen extends StatefulWidget {
  final String code;
  final bool isHost;
  const LiveCallScreen({super.key, required this.code, required this.isHost});
  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  io.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteSet = false, _hasRemote = false, _offered = false;
  bool _mic = true, _cam = true, _captionsOn = true, _ending = false, _cleaned = false;
  String _status = 'Starting camera and microphone...';
  final ValueNotifier<List<_Msg>> _chat = ValueNotifier<List<_Msg>>([]);
  final List<_Msg> _caps = [];
  final SpeechToText _stt = SpeechToText();
  Timer? _timer;
  int _secs = 0;

  int? get _myId => Api.I.user?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  // ---------------- start ----------------
  Future<void> _boot() async {
    try {
      await _local.initialize();
      await _remote.initialize();
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'}
      });
      _local.srcObject = _stream;
      if (mounted) setState(() => _status = 'Connecting...');
      await _createPc();
      _connect();
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not start the call: $e\nAllow camera and microphone access, then try again.');
    }
  }

  Future<void> _createPc() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // Free public TURN relay so the call also connects when the two
        // peers sit behind strict/carrier NATs on different networks.
        {
          'urls': [
            'turn:openrelay.metered.ca:80',
            'turn:openrelay.metered.ca:443',
            'turn:openrelay.metered.ca:443?transport=tcp',
          ],
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    for (final t in _stream!.getTracks()) {
      await pc.addTrack(t, _stream!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate != null && c.candidate!.isNotEmpty) {
        _socket?.emit('ice_candidate', {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
      }
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      _remote.srcObject = e.streams[0];
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secs++);
      });
      if (mounted) {
        setState(() {
          _hasRemote = true;
          _status = 'Connected';
        });
      }
    };
    pc.onConnectionState = (s) {
      if (mounted && s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() => _status = 'Connection failed. Both people need internet access; some networks need a TURN server.');
      }
    };
  }

  Future<void> _resetPc() async {
    try {
      await _pc?.close();
    } catch (_) {}
    _remoteSet = false;
    _pendingIce.clear();
    if (mounted) setState(() => _hasRemote = false);
    await _createPc();
  }

  // ---------------- signalling over Socket.IO ----------------
  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from((d is List && d.isNotEmpty ? d.first : d) as Map);

  void _connect() {
    final s = io.io(Api.baseUrl, io.OptionBuilder().setTransports(['websocket']).setAuth({'token': Api.I.token}).disableAutoConnect().build());
    _socket = s;
    s.onConnect((_) {
      s.emitWithAck('join_room', {'code': widget.code}, ack: (data) {
        final res = data is List && data.isNotEmpty ? data.first : data;
        if (res is Map && res['ok'] == true) {
          if (mounted) setState(() => _status = widget.isHost ? 'Waiting for the other person...\nShare the code below.' : 'Joined. Connecting...');
          _startCaptions();
        } else if (mounted) {
          setState(() => _status = 'Could not join: ${res is Map ? res['error'] : res}');
        }
      });
    });
    s.onConnectError((e) {
      if (mounted) setState(() => _status = 'Cannot reach the server at ${Api.baseUrl}.');
    });
    s.on('peer_joined', (_) async {
      if (!widget.isHost) return;
      if (_offered) await _resetPc();
      _offered = true;
      await _makeOffer();
    });
    s.on('offer', (d) async {
      final m = _map(d);
      await _pc?.setRemoteDescription(RTCSessionDescription(m['sdp'] as String, m['type'] as String));
      _remoteSet = true;
      await _flushIce();
      final ans = await _pc!.createAnswer();
      await _pc!.setLocalDescription(ans);
      s.emit('answer', {'sdp': ans.sdp, 'type': ans.type});
    });
    s.on('answer', (d) async {
      final m = _map(d);
      await _pc?.setRemoteDescription(RTCSessionDescription(m['sdp'] as String, m['type'] as String));
      _remoteSet = true;
      await _flushIce();
    });
    s.on('ice_candidate', (d) async {
      final m = _map(d);
      final c = RTCIceCandidate(m['candidate'] as String?, m['sdpMid'] as String?, (m['sdpMLineIndex'] as num?)?.toInt());
      if (_remoteSet) {
        await _pc?.addCandidate(c);
      } else {
        _pendingIce.add(c);
      }
    });
    s.on('caption', (d) {
      final m = _map(d);
      if (!mounted) return;
      setState(() {
        _caps.add(_Msg(m['speaker_id'] == _myId, m['text'] as String));
        if (_caps.length > 20) _caps.removeAt(0);
      });
    });
    s.on('chat_message', (d) {
      final m = _map(d);
      _chat.value = [..._chat.value, _Msg(m['sender_id'] == _myId, m['body'] as String)];
    });
    s.on('peer_left', (_) {
      if (mounted) setState(() => _status = 'The other person left the call.');
    });
    s.on('session_ended', (_) => _end(notify: false));
    s.connect();
  }

  Future<void> _makeOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _socket?.emit('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _flushIce() async {
    for (final c in _pendingIce) {
      await _pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  // ---------------- live captions (browser / phone speech recognition) ----------------
  Future<void> _startCaptions() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (st) {
          if ((st == 'done' || st == 'notListening') && _captionsOn && !_ending && mounted) {
            Future.delayed(const Duration(milliseconds: 350), _listenOnce);
          }
        },
        onError: (e) {
          if (_captionsOn && !_ending && mounted) Future.delayed(const Duration(seconds: 1), _listenOnce);
        },
      );
      if (ok) {
        _listenOnce();
      } else if (mounted) {
        setState(() => _captionsOn = false);
      }
    } catch (_) {
      if (mounted) setState(() => _captionsOn = false);
    }
  }

  void _listenOnce() {
    if (!_captionsOn || _ending || !mounted || !_mic || _stt.isListening) return;
    _stt.listen(
      onResult: (r) {
        final t = r.recognizedWords.trim();
        if (r.finalResult && t.isNotEmpty) _socket?.emitWithAck('caption', {'text': t, 'language': Api.I.language}, ack: (_) {});
      },
      localeId: Api.I.language == 'ur' ? 'ur_PK' : 'en_US',
    );
  }

  // ---------------- controls ----------------
  void _toggleMic() {
    setState(() => _mic = !_mic);
    for (final t in _stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = _mic;
    }
    if (!_mic) {
      _stt.stop();
    } else {
      _listenOnce();
    }
  }

  void _toggleCam() {
    setState(() => _cam = !_cam);
    for (final t in _stream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = _cam;
    }
  }

  void _toggleCaptions() {
    setState(() => _captionsOn = !_captionsOn);
    if (_captionsOn) {
      _startCaptions();
    } else {
      _stt.stop();
    }
  }

  void _sendChat(String text) => _socket?.emitWithAck('chat_message', {'body': text}, ack: (_) {});

  void _openChat() => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _ChatSheet(chat: _chat, onSend: _sendChat));

  Future<void> _end({bool notify = true}) async {
    if (_ending) return;
    _ending = true;
    if (notify) _socket?.emitWithAck('end_session', {}, ack: (_) {});
    await Future.delayed(const Duration(milliseconds: 200));
    await _cleanup();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    _timer?.cancel();
    _captionsOn = false;
    try {
      await _stt.stop();
    } catch (_) {}
    _socket?.dispose();
    _socket = null;
    try {
      await _pc?.close();
    } catch (_) {}
    for (final t in _stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _stream?.dispose();
    _local.srcObject = null;
    _remote.srcObject = null;
    await _local.dispose();
    await _remote.dispose();
  }

  @override
  void dispose() {
    _ending = true;
    _cleanup();
    _chat.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  String get _time => '${(_secs ~/ 60).toString().padLeft(2, '0')}:${(_secs % 60).toString().padLeft(2, '0')}';

  Widget _remoteTile() => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: _stage,
          child: _hasRemote
              ? RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [Ripples(size: 200, color: Color(0xFF8FB3EE)), Orb(Icons.person_rounded, size: 80)])),
                      Text(_status, textAlign: TextAlign.center, style: b(14, color: Colors.white70)),
                      if (widget.isHost && !_hasRemote) ...[
                        const SizedBox(height: 18),
                        Text('SESSION CODE', style: b(11, color: const Color(0xFF9DBDF0), w: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(widget.code, style: h(34, color: Colors.white)),
                          IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.code));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                              }),
                        ]),
                      ],
                    ]),
                  ),
                ),
        ),
      );

  Widget _pip() => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 96,
          height: 128,
          decoration: BoxDecoration(color: const Color(0xFF1A2A4A), border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(18)),
          child: _cam ? RTCVideoView(_local, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover) : const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 32),
        ),
      );

  Widget _captionsPanel() {
    final last = _caps.length > 3 ? _caps.sublist(_caps.length - 3) : _caps;
    return Glass(
      radius: 22,
      blur: true,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_captionsOn ? 'LIVE CAPTIONS' : 'CAPTIONS OFF', style: b(10.5, color: C.blue, w: FontWeight.w800)),
          const SizedBox(height: 6),
          if (last.isEmpty)
            Text(_captionsOn ? 'Speak and the captions appear here.' : 'Tap CC to turn captions on.', style: b(13.5))
          else
            for (var i = 0; i < last.length; i++)
              Text('${last[i].mine ? 'You' : 'Them'}: ${last[i].text}', style: b(i == last.length - 1 ? 15.5 : 13.5, color: i == last.length - 1 ? C.text : C.muted, w: i == last.length - 1 ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            maxWidth: 900,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(children: [
                  if (_hasRemote) const PulseDot(color: Color(0xFFFF4D6A), size: 7),
                  Text('${widget.code}${_hasRemote ? '  •  $_time' : ''}', style: b(14, color: C.text, w: FontWeight.w700)),
                  const Spacer(),
                  Pill(text: _hasRemote ? 'Connected' : 'Connecting', icon: _hasRemote ? Icons.check_circle_rounded : Icons.sync_rounded, hi: _hasRemote),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(children: [
                    Positioned.fill(child: _remoteTile()),
                    Positioned(top: 14, right: 14, child: _pip()),
                    Positioned(left: 14, right: 14, bottom: 14, child: _captionsPanel()),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Glass(
                  radius: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    RoundBtn(icon: _mic ? Icons.mic_rounded : Icons.mic_off_rounded, danger: !_mic, onTap: _toggleMic),
                    RoundBtn(icon: _cam ? Icons.videocam_rounded : Icons.videocam_off_rounded, danger: !_cam, onTap: _toggleCam),
                    RoundBtn(icon: Icons.closed_caption_rounded, active: _captionsOn, onTap: _toggleCaptions),
                    RoundBtn(icon: Icons.chat_bubble_outline_rounded, onTap: _openChat),
                    RoundBtn(icon: Icons.call_end_rounded, danger: true, onTap: () => _end()),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _ChatSheet extends StatefulWidget {
  final ValueNotifier<List<_Msg>> chat;
  final void Function(String) onSend;
  const _ChatSheet({required this.chat, required this.onSend});
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    widget.onSend(t);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Glass(
          radius: 28,
          blur: true,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 340,
            child: Column(children: [
              Text('Chat', style: h(18)),
              const SizedBox(height: 10),
              Expanded(
                child: ValueListenableBuilder<List<_Msg>>(
                  valueListenable: widget.chat,
                  builder: (_, list, __) => list.isEmpty
                      ? Center(child: Text('No messages yet', style: b(13.5)))
                      : ListView(children: [
                          for (final m in list)
                            Align(
                              alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: m.mine ? kGrad : null, color: m.mine ? null : C.sand),
                                child: Text(m.text, style: b(14, color: m.mine ? C.ink : C.text, w: FontWeight.w600)),
                              ),
                            ),
                        ]),
                ),
              ),
              Row(children: [
                Expanded(child: TextField(controller: _c, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Type a message'))),
                const SizedBox(width: 10),
                RoundBtn(icon: Icons.send_rounded, active: true, size: 48, onTap: _send),
              ]),
            ]),
          ),
        ),
      );
}
