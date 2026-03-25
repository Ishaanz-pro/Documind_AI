import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/document_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/ad_service.dart';
import 'services/firebase_service.dart';
import 'screens/gallery_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase
  try {
    await Firebase.initializeApp();
    // Anonymous sign in for quick start
    await FirebaseService().signInAnonymously();
  } catch (e) {
    debugPrint("Firebase not configured: \$e");
  }

  // Initialize Ads
  final adService = AdService();
  try {
    await adService.initialize();
  } catch(e) {
    debugPrint("AdMob not configured: \$e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()..init()),
        Provider<AdService>.value(value: adService),
      ],
      child: const DocuMindApp(),
    ),
  );
}

class DocuMindApp extends StatelessWidget {
  const DocuMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocuMind AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const GalleryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
