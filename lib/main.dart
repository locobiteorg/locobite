import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'repositories/discovery_repository.dart';
import 'repositories/mock_discovery_repository.dart';
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

  // Single point to swap Mock -> Real once the Rust backend is live.
  // e.g. final DiscoveryRepository repo = RealDiscoveryRepository(apiClient);
  static final DiscoveryRepository repo = MockDiscoveryRepository();

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
