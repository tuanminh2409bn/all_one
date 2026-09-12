import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/auth_service.dart';
import 'core/data_bootstrap.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1AA35A),
          primary: const Color(0xFF1AA35A),
        ),
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const [
          'Apple SD Gothic Neo',
          'Noto Sans KR',
          'Noto Sans',
          'Roboto',
        ],
      ),
      home: SplashScreen(auth: auth),
    );
  }
}
