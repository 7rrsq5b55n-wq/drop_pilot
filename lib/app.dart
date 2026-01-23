import 'package:flutter/material.dart';

import 'presentation/screens/onboarding_screen.dart';

class EcoRouteApp extends StatelessWidget {
  const EcoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drop Pilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue, // optional: change branding color
      ),
      home: const OnboardingScreen(),
    );
  }
}