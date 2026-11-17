import 'dart:async';
import 'package:flutter/foundation.dart';
import 'esp32_service.dart';
import 'models.dart';
import 'storage_service.dart';

// App-er "brain". Profile, chat, connection sob ekhane.
class AppState extends ChangeNotifier {
  final StorageService storage;
  UserProfile? profile;
  DeviceSettings settings;
  List<Conversation> conversations;
  late LoraService service;
  bool connected = false;
  bool unlocked = false;
  String? openChat; // ekhon kon chat khola ache
  Timer? _timer;
  bool _polling = false;

  AppState._(this.storage, this.profile, this.settings, this.conversations) {
    service = _makeService();
  }

  static Future<AppState> load() async {
    final storage = await StorageService.create();
    final state = AppState._(storage, storage.loadProfile(),
        storage.loadSettings(), storage.loadConversations());
    state._startPolling();
    return state;
  }

  LoraService _makeService() {
    if (settings.mockMode) return MockLoraService();
    if (settings.useWebSocket) return WebSocketLoraService(settings);
    return HttpLoraService(settings);
  }

  // Prottek 3 second-e ESP32 check kore ar notun message ane.
  void _startPolling() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || profile == null) return;
    _polling = true;
    try {
      final ok = connected
          ? await service.checkConnection()
          : await service.connectToDevice();
      if (ok != connected) {
        connected = ok;
        notifyListeners();
      }
      if (!ok) return;

      final r = await service.fetchMessages();
      var changed = false;

      for (final id in r.deliveredIds) {
        for (final c in conversations) {
          for (final m in c.messages) {
            if (m.id == id && m.isMine && m.status != MessageStatus.delivered) {
              m.status = MessageStatus.delivered;
              changed = true;
            }
          }
        }
      }

      for (final m in r.messages) {
        final me = profile!.rollNumber;
        if (m.fromRoll == me) continue; // nijer message echo hole ignore
        if (m.toRoll != null && m.toRoll != me) continue; // onno-r jonno
        final c = _getOrCreate(m.fromRoll, m.fromName);
        final already = c.messages.any((x) => x.id == m.id);
        await service.sendAck(id: m.id, toRoll: m.fromRoll);
        if (already) continue; // abar eshe gele duplicate dekhabo na
        c.messages.add(ChatMessage(
          id: m.id,
          text: m.text,
          isMine: false,
          time: DateTime.now(),
        ));
        if (openChat != c.rollNumber) c.unread++;
        changed = true;
      }

      if (changed) {
        await storage.saveConversations(conversations);
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Conversation _getOrCreate(String roll, String name) {
    for (final c in conversations) {
      if (c.rollNumber == roll) return c;
    }
    final c = Conversation(rollNumber: roll, name: name, messages: []);
    conversations.add(c);
    return c;
  }

  List<Conversation> get sortedConversations {
    final list = List<Conversation>.of(conversations);
    int t(Conversation c) => c.lastMessage?.time.millisecondsSinceEpoch ?? 0;
    list.sort((a, b) => t(b).compareTo(t(a)));
    return list;
  }

  Future<Conversation> startConversation(String roll, String name) async {
    final c = _getOrCreate(roll, name);
    await storage.saveConversations(conversations);
    notifyListeners();
    return c;
  }

  Future<void> markRead(Conversation c) async {
    if (c.unread == 0) return;
    c.unread = 0;
    await storage.saveConversations(conversations);
    notifyListeners();
  }

  Future<void> sendText(Conversation c, String text) async {
    final msg = ChatMessage(
      id: '${profile!.rollNumber}-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isMine: true,
      time: DateTime.now(),
      status: MessageStatus.sending,
    );
    c.messages.add(msg);
    notifyListeners();

    final ok = await service.sendMessage(
      me: profile!,
      toRoll: c.rollNumber,
      id: msg.id,
      text: text,
    );
    // ack age eshe gele "delivered" ke "sent" diye overwrite korbo na
    if (msg.status == MessageStatus.sending) {
      msg.status = ok ? MessageStatus.sent : MessageStatus.failed;
    }
    await storage.saveConversations(conversations);
    notifyListeners();
  }

  // ---- Profile ----
  Future<void> saveProfile(UserProfile p) async {
    profile = p;
    unlocked = true;
    await storage.saveProfile(p);
    notifyListeners();
    _startPolling();
  }

  bool unlock(String password) {
    if (password == profile?.password) {
      unlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ---- Settings ----
  Future<void> updateSettings(DeviceSettings s) async {
    await service.disconnect();
    settings = s;
    service = _makeService();
    connected = false;
    await storage.saveSettings(s);
    notifyListeners();
    _startPolling();
  }

  Future<void> resetAll() async {
    _timer?.cancel();
    await service.disconnect();
    await storage.clearAll();
    profile = null;
    settings = const DeviceSettings();
    conversations = [];
    service = _makeService();
    connected = false;
    unlocked = false;
    notifyListeners();
  }
}
