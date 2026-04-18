import 'package:flutter/material.dart';

class AppTheme {
  // ── Couleurs principales ────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF1a2540);
  static const Color primaryLight= Color(0xFF2d3f6b);
  static const Color accent      = Color(0xFF3b5bdb);
  static const Color success     = Color(0xFF2b8a3e);
  static const Color danger      = Color(0xFFc92a2a);
  static const Color warning     = Color(0xFFe67700);
  static const Color info        = Color(0xFF1971c2);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color background  = Color(0xFFf0f2f5);
  static const Color border      = Color(0xFFdee2e6);
  static const Color textPrimary = Color(0xFF212529);
  static const Color textMuted   = Color(0xFF6c757d);

  // ── Rôles couleurs ──────────────────────────────────────────────────────────
  static const Color dgColor  = Color(0xFF1a2540);
  static const Color rhColor  = Color(0xFF1971c2);
  static const Color empColor = Color(0xFF1A237E);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textMuted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: border, space: 1),
  );
}

// ── Constantes de statuts ──────────────────────────────────────────────────────
class StatusConfig {
  static Map<String, Map<String, dynamic>> attendance = {
    'present':       {'label': 'Présence',           'icon': '✅', 'color': Color(0xFF2b8a3e)},
    'sick':          {'label': 'Maladie',             'icon': '🏥', 'color': Color(0xFF1971c2)},
    'maternity':     {'label': 'Maternité',           'icon': '🤱', 'color': Color(0xFF1971c2)},
    'leave':         {'label': 'Congés',              'icon': '🏖️', 'color': Color(0xFFe67700)},
    'work_accident': {'label': 'Accident de travail', 'icon': '⚠️', 'color': Color(0xFFc92a2a)},
    'suspension':    {'label': 'Mise à pied',         'icon': '🚫', 'color': Color(0xFF868e96)},
    'absent':        {'label': 'Absence',             'icon': '❌', 'color': Color(0xFFc92a2a)},
    'permission':    {'label': 'Permission',          'icon': '🕐', 'color': Color(0xFFe67700)},
    'mission':       {'label': 'Mission',             'icon': '🚀', 'color': Color(0xFF2b8a3e)},
    'holiday':       {'label': 'Jour férié',          'icon': '🎉', 'color': Color(0xFF1971c2)},
  };
}
