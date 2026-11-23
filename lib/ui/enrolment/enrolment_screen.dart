import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/attendance_provider.dart';

class EnrolmentScreen extends ConsumerStatefulWidget {
  const EnrolmentScreen({super.key});

  @override
  ConsumerState<EnrolmentScreen> createState() => _EnrolmentScreenState();
}

class _EnrolmentScreenState extends ConsumerState<EnrolmentScreen> {
  final _form = GlobalKey<FormState>();
  final _studentId = TextEditingController();
  final _name = TextEditingController();
  bool _consent = false;
  bool _saving = false;

  @override
  void dispose() {
    _studentId.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(attendanceProvider.notifier)
          .enrol(studentId: _studentId.text, name: _name.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolment could not be saved: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enrol this device')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                key: const Key('studentId'),
                controller: _studentId,
                textCapitalization: TextCapitalization.characters,
                maxLength: 32,
                decoration: const InputDecoration(labelText: 'Student ID'),
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9/_-]{3,32}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Use 3 to 32 letters, digits, / _ or -',
              ),
              TextFormField(
                key: const Key('name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                title: const Text(
                  'I agree that each attempt records my ID, name, a random '
                  'device ID, the time, my distance from campus with its '
                  'accuracy, how long the checks took and the outcome. Fingerprint and face '
                  'data never leave the phone.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _consent && !_saving ? _submit : null,
                child: const Text('Enrol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
