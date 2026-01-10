import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService with ChangeNotifier {
  static const String _userNameKey = 'user_name';
  static const String _genderKey = 'user_gender';
  static const String _avatarIndexKey = 'user_avatar_index';

  String _userName = '';
  String _gender = ''; // 'male' or 'female'
  int _avatarIndex = 0;
  bool _isInitialized = false;

  UserService() {
    _loadUser();
  }

  String get userName => _userName;
  String get gender => _gender;
  int get avatarIndex => _avatarIndex;
  bool get hasName => _userName.isNotEmpty;
  bool get isInitialized => _isInitialized;

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_userNameKey) ?? '';
    _gender = prefs.getString(_genderKey) ?? '';
    _avatarIndex = prefs.getInt(_avatarIndexKey) ?? 0;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setProfile({
    required String name,
    required String gender,
    int? avatarIndex,
  }) async {
    _userName = name;
    _gender = gender;
    
    // If no avatar index provided, assign default based on gender
    if (avatarIndex == null) {
      _avatarIndex = (gender == 'male') ? 1 : 0;
    } else {
      _avatarIndex = avatarIndex;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, _userName);
    await prefs.setString(_genderKey, _gender);
    await prefs.setInt(_avatarIndexKey, _avatarIndex);
    notifyListeners();
  }

  Future<void> updateAvatar(int index) async {
    _avatarIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatarIndexKey, _avatarIndex);
    notifyListeners();
  }

  Future<void> updateGender(String gender) async {
    _gender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, _gender);
    notifyListeners();
  }
}
