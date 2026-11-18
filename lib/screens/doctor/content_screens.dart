import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/record_media.dart';
import '../content/content_views.dart';

/// Doctor: blogs with images and videos, shown to patients in Explore.
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<BlogPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/api/posts') as List;
      if (mounted) {
        setState(() {
          _posts = data.map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open([BlogPost? post]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PostEditor(post: post)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Blogs', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('New blog'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (!_loading && _posts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  'Share health tips with your patients: write a blog, add photos or a video.',
                  textAlign: TextAlign.center,
                  style: AppText.inter(color: AppColors.textMuted),
                ),
              ),
            for (final p in _posts)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: BlogCard(post: p, onTap: () => _open(p))),
          ],
        ),
      ),
    );
  }
}

class _PostEditor extends StatefulWidget {
  const _PostEditor({this.post});

  final BlogPost? post;

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late final _title = TextEditingController(text: widget.post?.title ?? '');
  late final _body = TextEditingController(text: widget.post?.body ?? '');
  late final _video = TextEditingController(text: widget.post?.videoUrl ?? '');
  late bool _published = widget.post?.published ?? true;
  late final List<PostMediaRef> _media = [...?widget.post?.media];
  final List<PickedUpload> _pending = [];
  bool _saving = false;

  Future<void> _add(String source) async {
    final f = await pickUpload(source);
    if (f != null) setState(() => _pending.add(f));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runAction(context, () async {
      final body = {'title': _title.text.trim(), 'body': _body.text.trim(), 'videoUrl': _video.text.trim(), 'published': _published};
      var id = widget.post?.id;
      if (id == null) {
        id = ((await api.post('/api/posts', body)) as Map<String, dynamic>)['id'] as int;
      } else {
        await api.put('/api/posts/$id', body);
      }
      for (final f in _pending) {
        await api.uploadPicked('/api/posts/$id/media', f);
      }
    });
    if (ok) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    if (await runAction(context, () => api.delete('/api/posts/${widget.post!.id}'))) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.post == null ? 'New blog' : 'Edit blog', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (widget.post != null) IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          ),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.inter(fontSize: 15, height: 1.55),
            decoration: const InputDecoration(hintText: 'Write your tips, advice or story...', border: InputBorder.none),
          ),
          const Divider(),
          Text('Photos & videos', style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _media)
                _Thumb(
                  child: m.isVideo
                      ? const Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryDark, size: 34)
                      : Image.network(mediaUrl(m.id), fit: BoxFit.cover),
                ),
              for (final f in _pending)
                _Thumb(
                  onRemove: () => setState(() => _pending.remove(f)),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      child: Text(f.name, maxLines: 3, textAlign: TextAlign.center, style: AppText.inter(fontSize: 10.5)),
                    ),
                  ),
                ),
              _AddTile(icon: Icons.photo_library_outlined, label: 'Photo', onTap: () => _add('gallery')),
              _AddTile(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: () => _add('camera')),
              _AddTile(icon: Icons.videocam_outlined, label: 'Video', onTap: () => _add('video')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _video,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'YouTube or video link (optional)', prefixIcon: Icon(Icons.link_rounded)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _published,
            onChanged: (v) => setState(() => _published = v),
            title: const Text('Visible to patients'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: Text(_saving ? 'Saving & uploading...' : 'Publish'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, this.onRemove});

  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(width: 84, height: 84, color: AppColors.chipBlue, child: child),
        ),
        if (onRemove != null)
          Positioned(
            right: -6,
            top: -6,
            child: InkWell(
              onTap: onRemove,
              child: const CircleAvatar(radius: 11, backgroundColor: AppColors.danger, child: Icon(Icons.close, size: 14, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE3F5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryDark),
            const SizedBox(height: 4),
            Text(label, style: AppText.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Doctor: health programmes (blood donation, full body checkup...) shown to
/// nearby patients.
class CampsScreen extends StatefulWidget {
  const CampsScreen({super.key});

  @override
  State<CampsScreen> createState() => _CampsScreenState();
}

class _CampsScreenState extends State<CampsScreen> {
  List<Camp> _camps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/api/camps') as List;
      if (mounted) setState(() => _camps = data.map((e) => Camp.fromJson(e as Map<String, dynamic>)).toList());
    } on ApiException {
      // shown empty
    }
  }

  Future<void> _edit([Camp? camp]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CampEditor(camp: camp)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Health camps', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New camp'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            if (_camps.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  'Announce a blood donation camp, full body checkup or any health programme. Nearby patients see it.',
                  textAlign: TextAlign.center,
                  style: AppText.inter(color: AppColors.textMuted),
                ),
              ),
            for (final c in _camps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(onLongPress: () => _edit(c), child: CampCard(camp: c)),
              ),
            if (_camps.isNotEmpty)
              Text('Long-press a camp to edit it.', textAlign: TextAlign.center, style: AppText.inter(fontSize: 12, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

class _CampEditor extends StatefulWidget {
  const _CampEditor({this.camp});

  final Camp? camp;

  @override
  State<_CampEditor> createState() => _CampEditorState();
}

class _CampEditorState extends State<_CampEditor> {
  static const _kinds = ['Blood donation', 'Full body checkup', 'Eye checkup', 'Dental checkup', 'Vaccination', 'Other'];

  late final _title = TextEditingController(text: widget.camp?.title ?? '');
  late final _venue = TextEditingController(text: widget.camp?.venue ?? '');
  late final _city = TextEditingController(text: widget.camp?.city ?? '');
  late final _details = TextEditingController(text: widget.camp?.details ?? '');
  late final _fee = TextEditingController(text: '${widget.camp?.fee ?? 0}');
  late final _contact = TextEditingController(text: widget.camp?.contactPhone ?? '');
  late String _kind = widget.camp?.kind ?? 'Blood donation';
  late DateTime _start = widget.camp?.startsAt ?? DateTime.now().add(const Duration(days: 3)).copyWith(hour: 9, minute: 0);
  late DateTime _end = widget.camp?.endsAt ?? _start.add(const Duration(hours: 5));
  double? _lat;
  double? _lng;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.camp?.lat;
    _lng = widget.camp?.lng;
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
      _end = DateTime(d.year, d.month, d.day, _end.hour, _end.minute);
    });
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start ? _start : _end));
    if (t == null) return;
    setState(() {
      if (start) {
        _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
      } else {
        _end = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute);
      }
    });
  }

  String _iso(DateTime d) => d.toIso8601String().split('.').first;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _venue.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final body = {
      'title': _title.text.trim(),
      'kind': _kind,
      'startsAt': _iso(_start),
      'endsAt': _iso(_end),
      'venue': _venue.text.trim(),
      'city': _city.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'details': _details.text.trim(),
      'fee': int.tryParse(_fee.text) ?? 0,
      'contactPhone': _contact.text.trim(),
    };
    final ok = await runAction(context, () => widget.camp == null ? api.post('/api/camps', body) : api.put('/api/camps/${widget.camp!.id}', body));
    if (ok) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.camp == null ? 'New health camp' : 'Edit camp', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (widget.camp != null)
            IconButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await runAction(context, () => api.delete('/api/camps/${widget.camp!.id}'))) navigator.pop();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Wrap(
            runSpacing: 8,
            children: [for (final k in _kinds) FilterPill(label: k, selected: _kind == k, onTap: () => setState(() => _kind = k))],
          ),
          TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title, e.g. Free blood donation camp')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _pickDay, icon: const Icon(Icons.event_rounded, size: 18), label: Text(dayDate(_start)))),
            ],
          ),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('From ${clock(_start)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('To ${clock(_end)}'))),
            ],
          ),
          TextField(controller: _venue, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Venue')),
          TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City')),
          Row(
            children: [
              Icon(Icons.place_rounded, color: _lat == null ? AppColors.textFaint : AppColors.success),
              const SizedBox(width: 6),
              Expanded(child: Text(_lat == null ? 'Location not pinned' : 'Location pinned', style: AppText.inter(fontSize: 13))),
              TextButton(
                onPressed: () async {
                  final p = await currentPosition();
                  if (p != null) {
                    setState(() {
                      _lat = p.latitude;
                      _lng = p.longitude;
                    });
                  }
                },
                child: const Text("I'm at the venue"),
              ),
            ],
          ),
          TextField(controller: _details, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Details: tests, who can come, what to bring')),
          Row(
            children: [
              Expanded(child: TextField(controller: _fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fee (₹, 0 = free)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact phone'))),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: Text(_saving ? 'Saving...' : 'Publish camp'),
            ),
          ),
        ],
      ),
    );
  }
}
