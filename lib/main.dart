import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppOrientationLock.enforceMobilePortrait();
  runApp(const YugiLifeCounterApp());
}
