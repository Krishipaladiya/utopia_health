import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';

// ---------------------------------------------------------------- upload

/// Camera, gallery or a document, then uploads it to the patient record.
/// Returns true when something was uploaded.
Future<bool> pickAndUpload(BuildContext context, Patient patient) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to record', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _PickOption(icon: Icons.photo_camera_outlined, label: 'Camera', value: 'camera'),
                _PickOption(icon: Icons.photo_library_outlined, label: 'Gallery', value: 'gallery'),
                _PickOption(icon: Icons.description_outlined, label: 'Document', value: 'document'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  String? path;
  String? name;
  try {
    if (choice == 'document') {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png'],
      );
      path = file?.path;
      name = file?.name;
    } else {
      final image = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 2000,
      );
      path = image?.path;
      name = image?.name;
    }
  } catch (e) {
    debugPrint('Pick failed: $e');
  }
  if (path == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Uploading...'), duration: Duration(seconds: 30)));
  try {
    await clinic.uploadFile(patient, path, fileName: name);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Added to the record')));
    return true;
  } on ApiException catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    return false;
  }
}

class _PickOption extends StatelessWidget {
  const _PickOption({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primaryDark, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- view files

/// Image from the record, loaded with the login token.
class RecordImage extends StatelessWidget {
  const RecordImage({super.key, required this.fileId, this.fit = BoxFit.cover});

  final int fileId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      api.url('/api/files/$fileId'),
      headers: api.authHeaders,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(
              color: AppColors.chipBlue,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.chipBlue,
        child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
      ),
    );
  }
}

void openImage(BuildContext context, int fileId, String title) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, style: AppText.inter(fontSize: 15, color: Colors.white)),
        ),
        body: Center(
          child: Hero(
            tag: 'record-file-$fileId',
            child: InteractiveViewer(maxScale: 5, child: RecordImage(fileId: fileId, fit: BoxFit.contain)),
          ),
        ),
      ),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Downloads a document and opens it in the phone's viewer.
Future<void> openDocument(BuildContext context, int fileId, String fileName) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await api.download('/api/files/$fileId');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileId-$fileName');
    await file.writeAsBytes(bytes);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(content: Text('No app to open $fileName')));
    }
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
  }
}

// ---------------------------------------------------------------- voice

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Plays a voice message stored on the server.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.noteId, required this.seconds});

  final int noteId;
  final int seconds;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  String? _localPath;
  bool _loading = false;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.onPlayerStateChanged.listen((s) => mounted ? setState(() => _state = s) : null))
      ..add(_player.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null))
      ..add(_player.onDurationChanged.listen((d) => mounted ? setState(() => _duration = d) : null))
      ..add(_player.onPlayerComplete.listen((_) => mounted ? setState(() => _position = Duration.zero) : null));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_localPath == null) {
      setState(() => _loading = true);
      try {
        final bytes = await api.download('/api/notes/${widget.noteId}/audio');
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/voice-${widget.noteId}.m4a');
        await file.writeAsBytes(bytes);
        _localPath = file.path;
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.friendly)));
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    await _player.play(DeviceFileSource(_localPath!));
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration?.inMilliseconds ?? widget.seconds * 1000;
    final progress = total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final playing = _state == PlayerState.playing;

    return Row(
      children: [
        Material(
          color: AppColors.primaryDark,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _loading ? null : _toggle,
            child: SizedBox(
              width: 42,
              height: 42,
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.chipBlue,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _clock(playing || _position > Duration.zero ? _position.inSeconds : widget.seconds),
          style: AppText.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Records a voice message. Call [start], then [stop] to get the file.
class VoiceRecorder {
  final _recorder = AudioRecorder();
  DateTime? _startedAt;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: path);
    _startedAt = DateTime.now();
    return true;
  }

  /// The recorded file and its length, or null if it was too short.
  Future<(String, int)?> stop() async {
    final path = await _recorder.stop();
    final seconds = _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds;
    _startedAt = null;
    if (path == null || seconds < 1) return null;
    return (path, seconds);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _startedAt = null;
  }

  void dispose() => _recorder.dispose();
}
