import 'package:flutter/material.dart';
import 'app_state.dart';
import 'home_screen.dart' show timeText;
import 'models.dart';

class ChatScreen extends StatefulWidget {
  final AppState state;
  final String rollNumber;
  const ChatScreen({super.key, required this.state, required this.rollNumber});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  Conversation get _conv => widget.state.conversations
      .firstWhere((c) => c.rollNumber == widget.rollNumber);

  @override
  void initState() {
    super.initState();
    widget.state.openChat = widget.rollNumber;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.state.markRead(_conv));
  }

  @override
  void dispose() {
    widget.state.openChat = null;
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.state.sendText(_conv, text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final conv = _conv;
        final msgs = conv.messages;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conv.name),
                Text('Roll no: ${conv.rollNumber}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: msgs.isEmpty
                    ? const Center(child: Text('Kono message nai. Hello bolun!'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) =>
                            _Bubble(message: msgs[msgs.length - 1 - i]),
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: 150, // LoRa packet choto, tai limit
                          buildCounter: (_,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _send, child: const Text('Send')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  IconData _icon(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeText(message.time),
                    style: Theme.of(context).textTheme.bodySmall),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(_icon(message.status),
                      size: 14,
                      color: message.status == MessageStatus.failed
                          ? scheme.error
                          : null),
                  if (message.status == MessageStatus.failed)
                    Text(' Failed',
                        style: TextStyle(fontSize: 11, color: scheme.error)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
