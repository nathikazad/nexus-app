import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    surface: Colors.white,
    onSurface: AppColors.slate900,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: Colors.white,
      elevation: 0,
    ),
    dividerColor: AppColors.slate200,
    fontFamily: 'Roboto',
  );
}
