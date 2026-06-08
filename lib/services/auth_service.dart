import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';
import 'api_client.dart';

/// Thrown by [AuthService.signInWithGoogle] when sign-in fails for a reason the
/// user should be told about (e.g. the API server is unreachable). A plain
/// user-cancelled popup does NOT raise this — it returns null instead.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

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

  /// Firebase error codes that mean the user aborted the popup/flow themselves.
  /// These are silent (return null), not surfaced as an error.
  static const Set<String> _cancelCodes = <String>{
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'user-cancelled',
  };

  Future<AppUser?> signInWithGoogle() async {
    final UserCredential credential;
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      credential = kIsWeb
          ? await _firebaseAuth.signInWithPopup(googleProvider)
          : await _firebaseAuth.signInWithProvider(googleProvider);
    } on FirebaseAuthException catch (e) {
      // User closed the popup / aborted: no error to show.
      if (_cancelCodes.contains(e.code)) return null;
      throw AuthException(e.message ?? e.code);
    }

    try {
      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('No Firebase user returned');
      }

      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw const AuthException('Could not obtain Firebase ID token');
      }

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
    } on AuthException {
      rethrow;
    } catch (e) {
      // Server unreachable, non-2xx, malformed response, etc. Firebase login
      // succeeded but the app session could not be established.
      throw AuthException(e.toString());
    }
  }

  /// Mint a fresh server JWT from a force-refreshed Firebase ID token.
  ///
  /// Wired into [ApiClient.onRefresh] so a 401 triggers a transparent refresh +
  /// retry. Returns the new JWT, or null (after signing out) when refresh is
  /// impossible — letting the caller surface the original auth failure.
  Future<String?> refreshToken() async {
    try {
      final User? firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        await signOut();
        return null;
      }

      final String? idToken = await firebaseUser.getIdToken(true);
      if (idToken == null) {
        await signOut();
        return null;
      }

      final Map<String, dynamic> response = await _apiClient.post(
        '/auth/firebase',
        <String, dynamic>{'idToken': idToken},
      );

      final String token = response['token'] as String;
      final AppUser refreshed = (_currentUser ??
              AppUser.fromJson(<String, dynamic>{
                'id': response['user']['id'] as String,
                'email': response['user']['email'] as String,
                'displayName': response['user']['displayName'] as String,
                'token': token,
              }))
          .copyWith(token: token);

      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(
        key: 'current_user',
        value: jsonEncode(refreshed.toJson()),
      );
      _currentUser = refreshed;
      notifyListeners();
      return token;
    } catch (_) {
      await signOut();
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
