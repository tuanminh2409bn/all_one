import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/auth_service.dart';
import 'core/data_bootstrap.dart';
import 'ui/app_theme.dart';
import 'ui/design_canvas.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await showDeviceStatusBar(darkIcons: true, backgroundColor: Colors.white);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final auth = AuthService();
  await auth.initialize();
  await initializeUserData(auth);
  runApp(AllOneApp(auth: auth));
}

class AllOneApp extends StatelessWidget {
  const AllOneApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NH올원뱅크',
      debugShowCheckedModeBanner: false,
      theme: buildAllOneTheme(),
      home: SplashScreen(auth: auth),
    );
  }
}
