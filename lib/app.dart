import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'splash/splash_screen.dart';

class AshRiseApp extends StatelessWidget {
  const AshRiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ash Rise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.charcoal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emberOrange,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
