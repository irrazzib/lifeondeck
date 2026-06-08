import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.token,
  });

  final String id;
  final String email;
  final String displayName;
  final String token;

  AppUser copyWith({String? token}) => AppUser(
    id: id,
    email: email,
    displayName: displayName,
    token: token ?? this.token,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'token': token,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    token: json['token'] as String,
  );
}
