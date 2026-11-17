// Ekbar chalaben: dart run tool/setup.dart
// Ei script platform folder (android, ios, windows, macos) banay
// ar ESP32 (http) er jonno dorkari permission add kore.
import 'dart:io';

Future<void> main() async {
  print('1/3  Platform folder toiri hocche (flutter create)...');
  final r = await Process.run(
    'flutter',
    ['create', '--platforms=android,ios,windows,macos', '.'],
    runInShell: true,
  );
  stdout.write(r.stdout);
  stderr.write(r.stderr);
  if (r.exitCode != 0) {
    print('flutter create fail korse. Flutter install ache kina check korun.');
    exit(1);
  }

  // Template-er default test file muchhe fela (nahole error dey)
  final t = File('test/widget_test.dart');
  if (t.existsSync()) t.deleteSync();

  print('2/3  Permission add kora hocche...');
  _patchAndroid();
  _patchIos();
  _patchMacos('macos/Runner/DebugProfile.entitlements');
  _patchMacos('macos/Runner/Release.entitlements');

  print('3/3  Package install (flutter pub get)...');
  final p = await Process.run('flutter', ['pub', 'get'], runInShell: true);
  stdout.write(p.stdout);
  stderr.write(p.stderr);

  print('\nShesh! Ekhon cholan: flutter run -d windows  (ba apnar device)');
}

void _patchAndroid() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }
  if (!s.contains('usesCleartextTraffic')) {
    s = s.replaceFirst('<application', '<application\n        android:usesCleartextTraffic="true"');
  }
  f.writeAsStringSync(s);
  print('   Android OK');
}

void _patchIos() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (!s.contains('NSAllowsArbitraryLoads')) {
    const add = '''
	<key>NSAppTransportSecurity</key>
	<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
	<key>NSLocalNetworkUsageDescription</key>
	<string>Connect to the nearby ESP32 device</string>
''';
    final i = s.lastIndexOf('</dict>');
    s = s.substring(0, i) + add + s.substring(i);
    f.writeAsStringSync(s);
  }
  print('   iOS OK');
}

void _patchMacos(String path) {
  final f = File(path);
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (!s.contains('com.apple.security.network.client')) {
    s = s.replaceFirst('<dict>',
        '<dict>\n\t<key>com.apple.security.network.client</key>\n\t<true/>');
    f.writeAsStringSync(s);
  }
  print('   macOS OK ($path)');
}
