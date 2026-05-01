import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({super.key});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController(text: 'NoGi Fundamentals');
  final _descriptionCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '20');

  String _courseType = 'grappling';
  String _level = 'all_levels';
  int? _coachId;

  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  int _durationMinutes = 60;

  bool _isRecurring = false;
  int _recurrenceWeeks = 8;

  bool _loading = false;
  String? _error;
  List<Member> _coaches = [];

  @override
  void initState() {
    super.initState();
    _loadCoaches();
  }

  Future<void> _loadCoaches() async {
    try {
      final members = await context.read<AuthProvider>().api.getMembers();
      setState(() {
        _coaches = members
            .where((m) => m.role == 'coach' || m.role == 'admin')
            .toList();
      });
    } catch (_) {}
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<AuthProvider>().api;
      final capacity = int.parse(_capacityCtrl.text);
      final startDateTime = _combine(_date, _start);
      final count = _isRecurring ? _recurrenceWeeks : 1;

      for (int i = 0; i < count; i++) {
        final start = startDateTime.add(Duration(days: 7 * i));
        final end = start.add(Duration(minutes: _durationMinutes));

        await api.createCourse(
          name: _nameCtrl.text.trim(),
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          courseType: _courseType,
          level: _level,
          startTime: start,
          endTime: end,
          maxCapacity: capacity,
          coachId: _coachId,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Créer un cours'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          const Text(
            'Build the\nWeekly Schedule',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 40,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom du cours'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nom obligatoire' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _courseType,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'grappling', child: Text('NoGi Grappling')),
                      DropdownMenuItem(value: 'wrestling', child: Text('Wrestling')),
                      DropdownMenuItem(value: 'mma', child: Text('MMA')),
                      DropdownMenuItem(value: 'other', child: Text('Autre')),
                    ],
                    onChanged: (v) => setState(() => _courseType = v!),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _level,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(labelText: 'Niveau'),
                    items: const [
                      DropdownMenuItem(value: 'beginner', child: Text('Débutant')),
                      DropdownMenuItem(value: 'intermediate', child: Text('Intermédiaire')),
                      DropdownMenuItem(value: 'advanced', child: Text('Avancé')),
                      DropdownMenuItem(value: 'all_levels', child: Text('Tous niveaux')),
                    ],
                    onChanged: (v) => setState(() => _level = v!),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    value: _coachId,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(labelText: 'Coach assigné'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucun coach'),
                      ),
                      ..._coaches.map(
                        (m) => DropdownMenuItem<int?>(
                          value: m.id,
                          child: Text(m.fullName),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _coachId = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacité'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Capacité invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          label: 'Date',
                          value: dateLabel,
                          icon: Icons.calendar_month,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerTile(
                          label: 'Heure',
                          value: _start.format(context),
                          icon: Icons.schedule,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _start,
                            );
                            if (picked != null) setState(() => _start = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _durationMinutes,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(labelText: 'Durée'),
                    items: const [
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                      DropdownMenuItem(value: 75, child: Text('75 min')),
                      DropdownMenuItem(value: 90, child: Text('90 min')),
                    ],
                    onChanged: (v) => setState(() => _durationMinutes = v!),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    value: _isRecurring,
                    activeColor: AppColors.gold,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Cours récurrent',
                      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Ex : NoGi Fundamentals tous les mardis 18h',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    onChanged: (v) => setState(() => _isRecurring = v),
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _recurrenceWeeks,
                      dropdownColor: AppColors.surface2,
                      decoration: const InputDecoration(labelText: 'Répéter pendant'),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4 semaines')),
                        DropdownMenuItem(value: 8, child: Text('8 semaines')),
                        DropdownMenuItem(value: 12, child: Text('12 semaines')),
                        DropdownMenuItem(value: 16, child: Text('16 semaines')),
                      ],
                      onChanged: (v) => setState(() => _recurrenceWeeks = v!),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(
                        _loading
                            ? 'Création...'
                            : _isRecurring
                                ? 'Créer $_recurrenceWeeks cours'
                                : 'Créer le cours',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}