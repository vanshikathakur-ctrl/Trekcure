import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized colors & styles so every screen looks consistent.
class AppColors {
  static const primaryGreen = Color(0xFF1B7A3D);
  static const darkGreen = Color(0xFF0F5C2A);
  static const lightGreenBg = Color(0xFFE9F7EE);
  static const dangerRed = Color(0xFFE23B3B);
  static const dangerBgLight = Color(0xFFFDEBEB);
  static const warningOrange = Color(0xFFF2A93B);
  static const warningBgLight = Color(0xFFFEF4E4);
  static const infoBlue = Color(0xFF3B82C4);
  static const infoBgLight = Color(0xFFE8F2FB);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFF6B7280);
  static const cardGrey = Color(0xFFF5F6F8);
  static const border = Color(0xFFE5E7EB);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primaryGreen,
      scaffoldBackgroundColor: Colors.white,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardGrey,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Small reusable rounded-card container used all over the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
