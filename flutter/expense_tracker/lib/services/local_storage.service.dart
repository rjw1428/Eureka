import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  late SharedPreferences _preferences;

  LocalStorageService._internal();
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() {
    return _instance;
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool get showTotal => _preferences.getBool('showTotal') ?? true;
  Future<void> setShowTotal(bool value) async {
    await _preferences.setBool('showTotal', value);
  }

  String? get themeColor => _preferences.getString('themeColor');
  Future<void> setThemeColor(String color) async {
    await _preferences.setString('themeColor', color);
  }

  Future<void> onLogout() async {
    await _preferences.clear();
  }
}
