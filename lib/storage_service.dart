import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// Phone/computer-er local storage-e data save kore. Internet lage na.
class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  UserProfile? loadProfile() {
    final s = _prefs.getString('profile');
    if (s == null) return null;
    return UserProfile.fromJson(jsonDecode(s));
  }

  Future<void> saveProfile(UserProfile p) =>
      _prefs.setString('profile', jsonEncode(p.toJson()));

  DeviceSettings loadSettings() {
    final s = _prefs.getString('settings');
    if (s == null) return const DeviceSettings();
    return DeviceSettings.fromJson(jsonDecode(s));
  }

  Future<void> saveSettings(DeviceSettings d) =>
      _prefs.setString('settings', jsonEncode(d.toJson()));

  List<Conversation> loadConversations() {
    final s = _prefs.getString('conversations');
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveConversations(List<Conversation> list) => _prefs.setString(
      'conversations', jsonEncode(list.map((c) => c.toJson()).toList()));

  Future<void> clearAll() => _prefs.clear();
}
