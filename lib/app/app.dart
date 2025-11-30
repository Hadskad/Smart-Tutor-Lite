import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'main_navigation.dart';
import 'routes.dart';

class SmartTutorLiteApp extends StatelessWidget {
  const SmartTutorLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartTutor Lite',
      theme: AppTheme.light,
      home: const MainNavigation(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
