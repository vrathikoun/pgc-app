import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/academy_video.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class AcademyAdminScreen extends StatefulWidget {
  const AcademyAdminScreen({super.key});

  @override
  State<AcademyAdminScreen> createState() => _AcademyAdminScreenState();
}

class _AcademyAdminScreenState extends State<AcademyAdminScreen> {
  List<AcademyVideo>? _videos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; });
    try {
      final videos = await context.read<AuthProvider>().api.getAcademyVideos();
      if (mounted) setState(() => _videos = videos);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(AcademyVideo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer la vidéo', style: TextStyle(color: AppColors.text)),
        content: Text(
          'Supprimer « ${video.title} » ?',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await context.read<AuthProvider>().api.deleteAcademyVideo(video.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _openForm({AcademyVideo? video}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _VideoForm(
        video: video,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text(
          'Vidéos Academy',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.muted)));
    }

    if (_videos == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_videos!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined, color: AppColors.muted, size: 48),
            const SizedBox(height: 14),
            const Text(
              'Aucune vidéo pour le moment.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une vidéo'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    final sections = _videos!.map((v) => v.section).toSet().toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                section,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ..._videos!
                .where((v) => v.section == section)
                .map((video) => _VideoTile(
                      video: video,
                      onEdit: () => _openForm(video: video),
                      onDelete: () => _delete(video),
                    )),
          ],
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final AcademyVideo video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VideoTile({
    required this.video,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = 'https://img.youtube.com/vi/${video.youtubeId}/hqdefault.jpg';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            thumbnail,
            width: 72,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 72,
              height: 48,
              color: AppColors.surface2,
              child: const Icon(Icons.play_circle, color: AppColors.gold, size: 20),
            ),
          ),
        ),
        title: Text(
          video.title,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          video.youtubeId,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.muted, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoForm extends StatefulWidget {
  final AcademyVideo? video;
  final VoidCallback onSaved;

  const _VideoForm({this.video, required this.onSaved});

  @override
  State<_VideoForm> createState() => _VideoFormState();
}

class _VideoFormState extends State<_VideoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _youtubeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _orderCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.video?.title ?? '');
    _sectionCtrl = TextEditingController(text: widget.video?.section ?? '');
    _youtubeCtrl = TextEditingController(text: widget.video?.youtubeId ?? '');
    _descCtrl = TextEditingController(text: widget.video?.description ?? '');
    _orderCtrl = TextEditingController(text: (widget.video?.sortOrder ?? 0).toString());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sectionCtrl.dispose();
    _youtubeCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = context.read<AuthProvider>().api;
      final title = _titleCtrl.text.trim();
      final section = _sectionCtrl.text.trim();
      final youtubeId = _youtubeCtrl.text.trim();
      final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final sortOrder = int.tryParse(_orderCtrl.text) ?? 0;

      if (widget.video == null) {
        await api.createAcademyVideo(
          title: title,
          section: section,
          youtubeId: youtubeId,
          description: description,
          sortOrder: sortOrder,
        );
      } else {
        await api.updateAcademyVideo(
          widget.video!.id,
          title: title,
          section: section,
          youtubeId: youtubeId,
          description: description,
          sortOrder: sortOrder,
        );
      }

      widget.onSaved();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.video != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Modifier la vidéo' : 'Ajouter une vidéo',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            _field(_titleCtrl, 'Titre', required: true),
            const SizedBox(height: 12),
            _field(_sectionCtrl, 'Section (ex: Guard, Leglocks…)', required: true),
            const SizedBox(height: 12),
            _field(_youtubeCtrl, 'YouTube ID (ex: dQw4w9WgXcQ)', required: true),
            const SizedBox(height: 12),
            _field(_descCtrl, 'Description (optionnel)'),
            const SizedBox(height: 12),
            _field(_orderCtrl, 'Ordre (0, 1, 2…)'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        isEdit ? 'Enregistrer' : 'Ajouter',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
          : null,
    );
  }
}
