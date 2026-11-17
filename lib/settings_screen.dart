import 'package:flutter/material.dart';
import 'app_state.dart';
import 'esp32_service.dart';
import 'models.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _mock;
  late bool _ws;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _wsPort;
  late final TextEditingController _status;
  late final TextEditingController _send;
  late final TextEditingController _messages;
  late final TextEditingController _users;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _mock = s.mockMode;
    _ws = s.useWebSocket;
    _host = TextEditingController(text: s.host);
    _port = TextEditingController(text: '${s.port}');
    _wsPort = TextEditingController(text: '${s.wsPort}');
    _status = TextEditingController(text: s.statusPath);
    _send = TextEditingController(text: s.sendPath);
    _messages = TextEditingController(text: s.messagesPath);
    _users = TextEditingController(text: s.usersPath);
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _wsPort, _status, _send, _messages, _users]) {
      c.dispose();
    }
    super.dispose();
  }

  String _path(String v) {
    final t = v.trim();
    return t.startsWith('/') ? t : '/$t';
  }

  DeviceSettings _build() => DeviceSettings(
        mockMode: _mock,
        useWebSocket: _ws,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 80,
        wsPort: int.tryParse(_wsPort.text.trim()) ?? 81,
        statusPath: _path(_status.text),
        sendPath: _path(_send.text),
        messagesPath: _path(_messages.text),
        usersPath: _path(_users.text),
      );

  void _msg(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _test() async {
    _msg('Testing...');
    final b = _build();
    final LoraService svc =
        b.useWebSocket ? WebSocketLoraService(b) : HttpLoraService(b);
    final ok = await svc.connectToDevice();
    await svc.disconnect();
    if (!mounted) return;
    _msg(ok
        ? 'ESP32 response diyeche (Wi-Fi OK). LoRa test hoyni.'
        : 'ESP32 pawa jayni. Wi-Fi, IP, port, path check korun.');
  }

  Future<void> _save() async {
    await widget.state.updateSettings(_build());
    if (!mounted) return;
    _msg('Saved');
  }

  Future<void> _reset() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sob data muchhe felben?'),
        content: const Text('Profile, chat history, settings sob delete hobe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await widget.state.resetAll();
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: !_mock,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Mock mode (fake ESP32)'),
            subtitle: const Text('Real ESP32 use korte eta off korun'),
            value: _mock,
            onChanged: (v) => setState(() => _mock = v),
          ),
          SwitchListTile(
            title: const Text('WebSocket use korun (ws://IP:81)'),
            subtitle: const Text('Off korle HTTP API use hobe'),
            value: _ws,
            onChanged: _mock ? null : (v) => setState(() => _ws = v),
          ),
          const SizedBox(height: 8),
          _field('ESP32 IP address', _host),
          _field('WebSocket port', _wsPort, number: true),
          _field('HTTP port (HTTP mode-er jonno)', _port, number: true),
          _field('Status path', _status),
          _field('Send path', _send),
          _field('Messages path', _messages),
          _field('Users path (discovery)', _users),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: _test, child: const Text('Test connection')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _save, child: const Text('Save')),
              ),
            ],
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _reset,
            child: Text('Reset app (sob data delete)',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
