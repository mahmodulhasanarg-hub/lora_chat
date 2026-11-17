enum MessageStatus { sending, sent, delivered, failed }

class UserProfile {
  final String name;
  final String rollNumber;
  final String? password; // optional app lock

  const UserProfile({required this.name, required this.rollNumber, this.password});

  Map<String, dynamic> toJson() =>
      {'name': name, 'rollNumber': rollNumber, 'password': password};

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'],
        rollNumber: j['rollNumber'],
        password: j['password'],
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMine;
  final DateTime time;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.time,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isMine': isMine,
        'time': time.millisecondsSinceEpoch,
        'status': status.name,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        text: j['text'],
        isMine: j['isMine'],
        time: DateTime.fromMillisecondsSinceEpoch(j['time']),
        status: MessageStatus.values.byName(j['status']),
      );
}

class Conversation {
  final String rollNumber; // 7 digit, eta-i conversation-er id
  String name;
  final List<ChatMessage> messages;
  int unread;

  Conversation({
    required this.rollNumber,
    required this.name,
    required this.messages,
    this.unread = 0,
  });

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  Map<String, dynamic> toJson() => {
        'rollNumber': rollNumber,
        'name': name,
        'unread': unread,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        rollNumber: j['rollNumber'],
        name: j['name'],
        unread: j['unread'] ?? 0,
        messages: (j['messages'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ESP32 connection settings. Sob kichu Settings screen theke change kora jay.
class DeviceSettings {
  final bool mockMode;
  final bool useWebSocket; // true = WebSocket (port 81), false = HTTP
  final String host;
  final int port; // HTTP port
  final int wsPort; // WebSocket port
  final String statusPath;
  final String sendPath;
  final String messagesPath;
  final String usersPath;

  const DeviceSettings({
    this.mockMode = true,
    this.useWebSocket = true,
    this.host = '192.168.4.1',
    this.port = 80,
    this.wsPort = 81,
    this.statusPath = '/status',
    this.sendPath = '/send',
    this.messagesPath = '/messages',
    this.usersPath = '/users',
  });

  Map<String, dynamic> toJson() => {
        'mockMode': mockMode,
        'useWebSocket': useWebSocket,
        'host': host,
        'port': port,
        'wsPort': wsPort,
        'statusPath': statusPath,
        'sendPath': sendPath,
        'messagesPath': messagesPath,
        'usersPath': usersPath,
      };

  factory DeviceSettings.fromJson(Map<String, dynamic> j) {
    const d = DeviceSettings();
    return DeviceSettings(
      mockMode: j['mockMode'] ?? d.mockMode,
      useWebSocket: j['useWebSocket'] ?? d.useWebSocket,
      host: j['host'] ?? d.host,
      port: j['port'] ?? d.port,
      wsPort: j['wsPort'] ?? d.wsPort,
      statusPath: j['statusPath'] ?? d.statusPath,
      sendPath: j['sendPath'] ?? d.sendPath,
      messagesPath: j['messagesPath'] ?? d.messagesPath,
      usersPath: j['usersPath'] ?? d.usersPath,
    );
  }
}
