import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'repositories/discovery_repository.dart';
import 'repositories/real_discovery_repository.dart';
import 'screens/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // TODO: Add your Supabase Credentials here
  await Supabase.initialize(
    url: 'https://ymgclwzuyjhajumohagy.supabase.co',
    anonKey: 'sb_publishable_PcxfJcckKmr-2xn1CtYXYA_lx3VjMxH',
  );

  runApp(const LocoBiteApp());
}

class LocoBiteApp extends StatelessWidget {
  const LocoBiteApp({super.key});

  // Single swap point. Vendors/menus now come live from the shared backend
  // (the same data the merchant app writes). For offline design work use
  // MockDiscoveryRepository() from repositories/mock_discovery_repository.dart.
  static final DiscoveryRepository repo = RealDiscoveryRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocoBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
