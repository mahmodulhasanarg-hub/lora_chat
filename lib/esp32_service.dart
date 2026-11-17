import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

class IncomingMessage {
  final String id;
  final String fromRoll;
  final String fromName;
  final String text;
  final String? toRoll; // kar jonno message (jani na hole null)
  IncomingMessage(
      {required this.id,
      required this.fromRoll,
      required this.fromName,
      required this.text,
      this.toRoll});
}

class FetchResult {
  final List<IncomingMessage> messages;
  final List<String> deliveredIds; // ack pawa message id
  FetchResult(this.messages, this.deliveredIds);
}

class PeerUser {
  final String name;
  final String rollNumber;
  PeerUser(this.name, this.rollNumber);
}

// ESP32 er sathe kotha bolar "interface". Pore onno protocol (WebSocket, BLE)
// lagle sudhu notun class likhlei hobe, baki app change korte hobe na.
abstract class LoraService {
  Future<bool> connectToDevice();
  Future<bool> checkConnection();
  Future<bool> sendMessage({
    required UserProfile me,
    required String toRoll,
    required String id,
    required String text,
  });
  Future<FetchResult> fetchMessages();
  // Message pawar por sender-ke "pouchechi" janano (delivery ack)
  Future<void> sendAck({required String id, required String toRoll});
  Future<List<PeerUser>> discoverUsers();
  Future<void> disconnect();
}


class HttpLoraService implements LoraService {
  final DeviceSettings s;
  HttpLoraService(this.s);

  static const _timeout = Duration(seconds: 4);

  Uri _uri(String path) =>
      Uri(scheme: 'http', host: s.host, port: s.port, path: path);

  @override
  Future<bool> connectToDevice() => checkConnection();

  // ESP32 Wi-Fi-te pawa jacche kina. LoRa link verify kore na.
  @override
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(_uri(s.statusPath)).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> sendMessage({
    required UserProfile me,
    required String toRoll,
    required String id,
    required String text,
  }) async {
    try {
      final res = await http
          .post(
            _uri(s.sendPath),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'from': me.rollNumber,
              'name': me.name,
              'to': toRoll,
              'text': text,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return false;
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['ok'] == false) return false;
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<FetchResult> fetchMessages() async {
    final msgs = <IncomingMessage>[];
    final acks = <String>[];
    try {
      final res = await http.get(_uri(s.messagesPath)).timeout(_timeout);
      if (res.statusCode != 200) return FetchResult(msgs, acks);
      final data = jsonDecode(res.body);
      final list = data is Map ? data['messages'] : data;
      if (list is! List) return FetchResult(msgs, acks);
      for (final item in list) {
        if (item is! Map) continue;
        if (item['type'] == 'ack') {
          if (item['id'] != null) acks.add('${item['id']}');
        } else if (item['from'] != null && item['text'] != null) {
          msgs.add(IncomingMessage(
            id: '${item['id'] ?? DateTime.now().microsecondsSinceEpoch}',
            fromRoll: '${item['from']}',
            fromName: '${item['name'] ?? item['from']}',
            text: '${item['text']}',
          ));
        }
      }
    } catch (_) {}
    return FetchResult(msgs, acks);
  }

  @override
  Future<List<PeerUser>> discoverUsers() async {
    try {
      final res = await http.get(_uri(s.usersPath)).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data is Map ? data['users'] : data;
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .where((u) => u['roll'] != null)
          .map((u) => PeerUser('${u['name'] ?? u['roll']}', '${u['roll']}'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // HTTP firmware nijei ack pathay, tai app-er kichu korar nai
  @override
  Future<void> sendAck({required String id, required String toRoll}) async {}

  @override
  Future<void> disconnect() async {} // HTTP-te kono permanent connection nai
}


class WebSocketLoraService implements LoraService {
  final DeviceSettings s;
  WebSocketLoraService(this.s);

  WebSocketChannel? _ch;
  bool _open = false;
  bool _connecting = false;
  final List<IncomingMessage> _inbox = [];
  final List<String> _acks = [];

  @override
  Future<bool> connectToDevice() async {
    if (_open) return true;
    if (_connecting) return false;
    _connecting = true;
    try {
      final ch =
          WebSocketChannel.connect(Uri.parse('ws://${s.host}:${s.wsPort}'));
      try {
        await ch.ready.timeout(const Duration(seconds: 4));
      } catch (_) {
        ch.sink.close();
        return false;
      }
      _ch = ch;
      _open = true;
      ch.stream.listen(
        _onData,
        onDone: () {
          if (identical(_ch, ch)) _open = false;
        },
        onError: (_) {
          if (identical(_ch, ch)) _open = false;
        },
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _connecting = false;
    }
  }

  // WebSocket connection ekhono khola ache kina (LoRa link verify kore na).
  @override
  Future<bool> checkConnection() async => _open;

  void _onData(dynamic data) {
    if (data is! String) return;
    // ESP32 kokhono text-er age/pore kichu jure dite pare, tai { ... } ongshota nei
    final a = data.indexOf('{');
    final b = data.lastIndexOf('}');
    if (a < 0 || b <= a) return;
    try {
      final d = jsonDecode(data.substring(a, b + 1));
      if (d is! Map) return;
      if (d['t'] == 'a' && d['i'] != null) {
        _acks.add('${d['i']}');
      } else if (d['t'] == 'm' &&
          d['i'] != null &&
          d['f'] != null &&
          d['x'] != null) {
        _inbox.add(IncomingMessage(
          id: '${d['i']}',
          fromRoll: '${d['f']}',
          fromName: '${d['n'] ?? d['f']}',
          text: '${d['x']}',
          toRoll: d['o'] == null ? null : '${d['o']}',
        ));
      }
    } catch (_) {}
  }

  @override
  Future<bool> sendMessage({
    required UserProfile me,
    required String toRoll,
    required String id,
    required String text,
  }) async {
    if (!_open && !await connectToDevice()) return false;
    try {
      _ch!.sink.add(jsonEncode({
        't': 'm',
        'i': id,
        'f': me.rollNumber,
        'n': me.name,
        'o': toRoll,
        'x': text,
      }));
      // "sent" mane sudhu ESP32-r kache pouchechhe, LoRa-te gese kina jani na
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sendAck({required String id, required String toRoll}) async {
    if (!_open) return;
    try {
      _ch!.sink.add(jsonEncode({'t': 'a', 'i': id, 'o': toRoll}));
    } catch (_) {}
  }

  @override
  Future<FetchResult> fetchMessages() async {
    final r = FetchResult(List.of(_inbox), List.of(_acks));
    _inbox.clear();
    _acks.clear();
    return r;
  }

  // Ei protocol-e discovery nai
  @override
  Future<List<PeerUser>> discoverUsers() async => [];

  @override
  Future<void> disconnect() async {
    _open = false;
    final ch = _ch;
    _ch = null;
    try {
      ch?.sink.close();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------
// Mock: ESP32 charai test korar jonno. Sob kichu fake.
// ---------------------------------------------------------------
class MockLoraService implements LoraService {
  final List<IncomingMessage> _inbox = [];
  final List<String> _acks = [];

  @override
  Future<bool> connectToDevice() async => true;

  @override
  Future<bool> checkConnection() async => true;

  @override
  Future<bool> sendMessage({
    required UserProfile me,
    required String toRoll,
    required String id,
    required String text,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    Future.delayed(const Duration(seconds: 2), () => _acks.add(id));
    Future.delayed(const Duration(seconds: 4), () {
      _inbox.add(IncomingMessage(
        id: 'mock-$id',
        fromRoll: toRoll,
        fromName: 'User $toRoll',
        text: 'Mock reply to: "$text"',
      ));
    });
    return true;
  }

  @override
  Future<FetchResult> fetchMessages() async {
    final r = FetchResult(List.of(_inbox), List.of(_acks));
    _inbox.clear();
    _acks.clear();
    return r;
  }

  @override
  Future<void> sendAck({required String id, required String toRoll}) async {}

  @override
  Future<List<PeerUser>> discoverUsers() async => [
        PeerUser('Alice', '2345678'),
        PeerUser('Bob', '3456789'),
      ];

  @override
  Future<void> disconnect() async {}
}
