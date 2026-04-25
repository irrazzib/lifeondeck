import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._apiClient);

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    final String? saved = await _storage.read(key: 'current_user');
    if (saved != null) {
      try {
        _currentUser = AppUser.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
        // If Firebase session expired, clear local user too
        if (_firebaseAuth.currentUser == null) {
          await _clearUser();
          return;
        }
        notifyListeners();
      } catch (_) {
        await _clearUser();
      }
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential credential = kIsWeb
          ? await _firebaseAuth.signInWithPopup(googleProvider)
          : await _firebaseAuth.signInWithProvider(googleProvider);

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null) return null;

      final Map<String, dynamic> response = await _apiClient.post(
        '/auth/firebase',
        <String, dynamic>{'idToken': idToken},
      );

      final AppUser user = AppUser.fromJson(<String, dynamic>{
        'id': response['user']['id'] as String,
        'email': response['user']['email'] as String,
        'displayName': response['user']['displayName'] as String,
        'token': response['token'] as String,
      });

      await _storage.write(key: 'jwt_token', value: user.token);
      await _storage.write(key: 'current_user', value: jsonEncode(user.toJson()));
      _currentUser = user;
      notifyListeners();
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _clearUser();
  }

  Future<void> _clearUser() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'current_user');
    _currentUser = null;
    notifyListeners();
  }
}
