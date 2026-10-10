import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SubjectEntry {
  final TextEditingController name = TextEditingController();
  TimeOfDay? start;
  TimeOfDay? end;
  void dispose() => name.dispose();
}

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  static const _purple = Color(0xFF5B3FD6);
  static const _stepTitles = ['Details', 'Subjects', 'Review'];

  final _detailsKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _section = TextEditingController();
  final _course = TextEditingController();
  List<SubjectEntry> _subjects = [SubjectEntry()];

  int _step = 0;
  bool _saving = false;
  String? _subjectError;

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _course.dispose();
    for (final s in _subjects) {
      s.dispose();
    }
    super.dispose();
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _next() {
    if (_step == 0) {
      if (_detailsKey.currentState!.validate()) setState(() => _step = 1);
    } else if (_step == 1) {
      String? error;
      for (final s in _subjects) {
        if (s.name.text.trim().isEmpty || s.start == null || s.end == null) {
          error = 'Please fill in the subject and both times for every subject.';
          break;
        }
        if (_minutes(s.end!) <= _minutes(s.start!)) {
          error = 'End time must be later than start time.';
          break;
        }
      }
      setState(() {
        _subjectError = error;
        if (error == null) _step = 2;
      });
    }
  }

  void _back() => setState(() => _step--);

  Future<void> _pickTime(SubjectEntry s, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? s.start : s.end) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => isStart ? s.start = picked : s.end = picked);
    }
  }

  void _removeSubject(int i) {
    late SubjectEntry removed;
    setState(() => removed = _subjects.removeAt(i));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _reset() {
    _name.clear();
    _section.clear();
    _course.clear();
    final old = _subjects;
    _subjects = [SubjectEntry()];
    _step = 0;
    _subjectError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in old) {
        s.dispose();
      }
    });
  }

  Future<void> _save() async {
    final schedule = _subjects
        .map((s) => {
              'subject': s.name.text.trim(),
              'startTime': s.start!.format(context),
              'endTime': s.end!.format(context),
            })
        .toList();

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('profiles').add({
        'name': _name.text.trim(),
        'section': _section.text.trim(),
        'course': _course.text.trim(),
        'schedule': schedule,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(_reset);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: [_detailsStep, _subjectsStep, _reviewStep][_step](),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B3FD6), Color(0xFF8E6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const Text(
            'Create Your Profile',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _stepper(),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_stepTitles.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = _step > i ~/ 2;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                height: 3,
                color: done ? Colors.white : Colors.white38,
              ),
            ),
          );
        }
        final index = i ~/ 2;
        final active = index == _step;
        final done = index < _step;
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: (done || active) ? Colors.white : Colors.white24,
              child: done
                  ? const Icon(Icons.check, size: 18, color: _purple)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: active ? _purple : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _stepTitles[index],
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _card({Key? key, required Widget child}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A5B3FD6), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _purple),
      filled: true,
      fillColor: const Color(0xFFF7F5FF),
      border: border(const Color(0xFFE0DAFF)),
      enabledBorder: border(const Color(0xFFE0DAFF)),
      focusedBorder: border(_purple),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        decoration: _decoration(label, icon),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Please input $label' : null,
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEDE8FF),
            child: Icon(icon, color: _purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsStep() {
    return Form(
      key: _detailsKey,
      child: _card(
        child: Column(
          children: [
            _sectionTitle(Icons.badge_outlined, 'Personal details',
                'Tell us a little about your enrollment'),
            _field(_name, 'Name', Icons.person_outline),
            _field(_section, 'Section', Icons.groups_outlined),
            _field(_course, 'Course', Icons.school_outlined),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(
      String label, IconData icon, TimeOfDay? value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(label, icon)
            .copyWith(suffixIcon: const Icon(Icons.access_time, color: _purple)),
        child: Text(
          value == null ? 'Select time' : value.format(context),
          style: TextStyle(color: value == null ? Colors.black45 : Colors.black87),
        ),
      ),
    );
  }

  Widget _subjectsStep() {
    return Column(
      children: [
        for (int i = 0; i < _subjects.length; i++)
          _card(
            key: ObjectKey(_subjects[i]),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _purple,
                      child: Text('${i + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Subject ${i + 1}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (_subjects.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _removeSubject(i),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjects[i].name,
                  decoration: _decoration('Subject', Icons.menu_book_outlined),
                ),
                const SizedBox(height: 14),
                _timeTile('Start Time', Icons.play_circle_outline,
                    _subjects[i].start, () => _pickTime(_subjects[i], true)),
                const SizedBox(height: 14),
                _timeTile('End Time', Icons.flag_outlined, _subjects[i].end,
                    () => _pickTime(_subjects[i], false)),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _subjects.add(SubjectEntry())),
          icon: const Icon(Icons.add),
          label: const Text('Add another subject'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _purple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_subjectError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_subjectError!,
                style: const TextStyle(color: Colors.redAccent)),
          ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _purple, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            children: [
              _sectionTitle(Icons.fact_check_outlined, 'Review your details',
                  'Make sure everything looks right before saving'),
              _reviewRow(Icons.person_outline, 'Name', _name.text.trim()),
              const Divider(),
              _reviewRow(Icons.groups_outlined, 'Section', _section.text.trim()),
              const Divider(),
              _reviewRow(Icons.school_outlined, 'Course', _course.text.trim()),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Class schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        for (final s in _subjects)
          _card(
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: _purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name.text.trim(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${s.start!.format(context)} - ${s.end!.format(context)}',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    final isLast = _step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      color: Colors.white,
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _saving ? null : _back,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _saving ? null : (isLast ? _save : _next),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(isLast ? 'Save' : (_step == 0 ? 'Next' : 'Review')),
          ),
        ],
      ),
    );
  }
}