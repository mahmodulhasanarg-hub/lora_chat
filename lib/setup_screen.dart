import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'models.dart';

// Prothom bar app khulle ei screen asbe.
class SetupScreen extends StatefulWidget {
  final AppState state;
  const SetupScreen({super.key, required this.state});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _roll = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final pw = _password.text.trim();
    widget.state.saveProfile(UserProfile(
      name: _name.text.trim(),
      rollNumber: _roll.text.trim(),
      password: pw.isEmpty ? null : pw,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name likhun'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _roll,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Roll number (exactly 7 digit)',
                        border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length != 7)
                        ? 'Thik 7 digit lagbe'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'App password (optional)',
                        helperText:
                            'Sudhu simple lock. Strong security noy.',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _save, child: const Text('Start')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  final AppState state;
  const LockScreen({super.key, required this.state});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pw = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _unlock() {
    if (!widget.state.unlock(_pw.text)) {
      setState(() => _error = 'Password bhul');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locked')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 48),
                const SizedBox(height: 16),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _unlock, child: const Text('Unlock')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
