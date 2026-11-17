import 'package:flutter/material.dart';
import 'app_state.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(LoraChatApp(state: state));
}

class LoraChatApp extends StatelessWidget {
  final AppState state;
  const LoraChatApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoRa Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final p = state.profile;
          if (p == null) return SetupScreen(state: state);
          if (p.password != null && !state.unlocked) {
            return LockScreen(state: state);
          }
          return HomeScreen(state: state);
        },
      ),
    );
  }
}
