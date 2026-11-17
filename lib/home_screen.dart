import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'chat_screen.dart';
import 'esp32_service.dart';
import 'settings_screen.dart';

String timeText(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.sortedConversations;
        return Scaffold(
          appBar: AppBar(
            title: const Text('LoRa Chat'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(state: state)),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewChatScreen(state: state)),
            ),
            child: const Icon(Icons.add_comment),
          ),
          body: Column(
            children: [
              _profileCard(context),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('Kono chat nai. Niche + button chapun.'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final last = c.lastMessage;
                          return ListTile(
                            leading: CircleAvatar(
                                child: Text(c.name.isEmpty ? '?' : c.name[0])),
                            title: Text(c.name),
                            subtitle: Text(
                              last?.text ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: c.unread > 0
                                ? Badge(label: Text('${c.unread}'))
                                : (last == null
                                    ? null
                                    : Text(timeText(last.time))),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                    state: state, rollNumber: c.rollNumber),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileCard(BuildContext context) {
    final p = state.profile!;
    Color color;
    String text;
    if (state.settings.mockMode) {
      color = Colors.orange;
      text = 'Mock mode (ESP32 connected na)';
    } else if (state.connected) {
      color = Colors.green;
      text = 'ESP32 Wi-Fi-te pawa jacche (LoRa link verify kora hoyni)';
    } else {
      color = Colors.red;
      text = 'ESP32 pawa jacche na';
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
              radius: 28,
              child: Text(p.name[0], style: const TextStyle(fontSize: 24))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                Text('Roll no: ${p.rollNumber}'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(text)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Notun chat shuru korar screen
class NewChatScreen extends StatefulWidget {
  final AppState state;
  const NewChatScreen({super.key, required this.state});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _roll = TextEditingController();
  List<PeerUser> _found = [];
  bool _searching = false;
  String? _note;

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    setState(() {
      _searching = true;
      _note = null;
    });
    final users = await widget.state.service.discoverUsers();
    if (!mounted) return;
    setState(() {
      _found = users;
      _searching = false;
      if (users.isEmpty) {
        _note = 'Kono user pawa jayni (firmware discovery support na-o korte pare).';
      }
    });
  }

  Future<void> _start(String roll, String name) async {
    final c = await widget.state.startConversation(roll, name);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(state: widget.state, rollNumber: c.rollNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Friend-er name',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name likhun' : null,
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
                      labelText: 'Friend-er roll number (7 digit)',
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.length != 7) return 'Thik 7 digit lagbe';
                    if (v == widget.state.profile!.rollNumber) {
                      return 'Nijer sathe chat kora jabe na';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _start(_roll.text.trim(), _name.text.trim());
                      }
                    },
                    child: const Text('Start chat'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _searching ? null : _discover,
            icon: const Icon(Icons.search),
            label: Text(_searching ? 'Searching...' : 'Nearby user khujun'),
          ),
          if (_note != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_note!)),
          for (final u in _found)
            ListTile(
              leading: CircleAvatar(child: Text(u.name[0])),
              title: Text(u.name),
              subtitle: Text('Roll no: ${u.rollNumber}'),
              onTap: () => _start(u.rollNumber, u.name),
            ),
        ],
      ),
    );
  }
}
