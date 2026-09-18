import 'package:flutter/material.dart';

enum SmartStockTheme { defaultLight, dark, blueSteel, sageField }

extension SmartStockThemeName on SmartStockTheme {
  String get label => switch (this) {
        SmartStockTheme.defaultLight => 'Default',
        SmartStockTheme.dark => 'Dark',
        SmartStockTheme.blueSteel => 'Blue Steel',
        SmartStockTheme.sageField => 'Sage Field',
      };
}

class SmartStockThemes {
  static const Color defaultPrimary = Color(0xFF2563EB);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  static ThemeData build(SmartStockTheme selected, {Color? accent}) {
    final spec = _spec(selected);
    final primary = accent ?? spec.primary;
    final brightness = spec.brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      surface: spec.surface,
      error: spec.error,
    ).copyWith(
      primaryContainer: _mix(primary, spec.surface, .16),
      secondary: spec.secondary,
      secondaryContainer: spec.secondaryContainer,
      outline: spec.outline,
      outlineVariant: spec.outlineVariant,
      surfaceContainerLowest: spec.card,
      surfaceContainerLow: spec.surfaceLow,
      surfaceContainer: spec.surfaceContainer,
      surfaceContainerHigh: _mix(spec.surface, spec.onSurface, .08),
      surfaceContainerHighest: _mix(spec.surface, spec.onSurface, .12),
      onSurface: spec.onSurface,
      onSurfaceVariant: spec.onSurfaceVariant,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: spec.background,
      canvasColor: spec.background,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: spec.card,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: spec.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onColor(primary),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: spec.surfaceLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            // Keep selected icons neutral/high-contrast instead of tinting them blue.
            // This is near-black on light themes and automatically adapts on dark themes.
            color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: spec.surfaceLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        // Selected labels stay primary-colored, while icons remain neutral/high-contrast.
        selectedIconTheme: IconThemeData(color: scheme.onSurface),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: primary, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(spec.surfaceLow),
        headingTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dataTextStyle: TextStyle(color: spec.onSurface, fontSize: 14),
        dividerThickness: .7,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF313244)
            : const Color(0xFF191B23),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }

  static _ThemeSpec _spec(SmartStockTheme t) => switch (t) {
        SmartStockTheme.defaultLight => const _ThemeSpec(
            brightness: Brightness.light,
            background: Color(0xFFFAF8FF),
            surface: Color(0xFFFAF8FF),
            surfaceLow: Color(0xFFF3F3FE),
            surfaceContainer: Color(0xFFEDEDF9),
            card: Colors.white,
            onSurface: Color(0xFF191B23),
            onSurfaceVariant: Color(0xFF434655),
            primary: Color(0xFF2563EB),
            secondary: Color(0xFF505F76),
            secondaryContainer: Color(0xFFD0E1FB),
            outline: Color(0xFF737686),
            outlineVariant: Color(0xFFC3C6D7),
            error: Color(0xFFBA1A1A),
          ),
        SmartStockTheme.dark => const _ThemeSpec(
            brightness: Brightness.dark,
            background: Color(0xFF1E1E2E),
            surface: Color(0xFF1E1E2E),
            surfaceLow: Color(0xFF181825),
            surfaceContainer: Color(0xFF313244),
            card: Color(0xFF181825),
            onSurface: Color(0xFFCDD6F4),
            onSurfaceVariant: Color(0xFFA6ADC8),
            primary: Color(0xFF89B4FA),
            secondary: Color(0xFFA6ADC8),
            secondaryContainer: Color(0xFF313244),
            outline: Color(0xFF585B70),
            outlineVariant: Color(0xFF45475A),
            error: Color(0xFFF38BA8),
          ),
        SmartStockTheme.blueSteel => const _ThemeSpec(
            brightness: Brightness.dark,
            background: Color(0xFF1A2332),
            surface: Color(0xFF1A2332),
            surfaceLow: Color(0xFF111B27),
            surfaceContainer: Color(0xFF1E3A5F),
            card: Color(0xFF111B27),
            onSurface: Color(0xFFE0E8F0),
            onSurfaceVariant: Color(0xFF8AACCC),
            primary: Color(0xFF5BA3D9),
            secondary: Color(0xFF8AACCC),
            secondaryContainer: Color(0xFF1E3A5F),
            outline: Color(0xFF3D7AB5),
            outlineVariant: Color(0xFF2E4057),
            error: Color(0xFFFF8A8A),
          ),
        SmartStockTheme.sageField => const _ThemeSpec(
            brightness: Brightness.light,
            background: Color(0xFFF1F3E0),
            surface: Color(0xFFF1F3E0),
            surfaceLow: Color(0xFFE5EBD1),
            surfaceContainer: Color(0xFFD2DCB6),
            card: Colors.white,
            onSurface: Color(0xFF2C3329),
            onSurfaceVariant: Color(0xFF4A5E45),
            primary: Color(0xFF778873),
            secondary: Color(0xFF5C6E57),
            secondaryContainer: Color(0xFFD2DCB6),
            outline: Color(0xFF778873),
            outlineVariant: Color(0xFFA1BC98),
            error: Color(0xFFBA1A1A),
          ),
      };

  static Color _mix(Color a, Color b, double amount) => Color.lerp(a, b, amount)!;

  static Color _onColor(Color c) {
    final luminance = c.computeLuminance();
    return luminance < .45 ? Colors.white : const Color(0xFF1A1C24);
  }
}

class _ThemeSpec {
  const _ThemeSpec({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.card,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.secondary,
    required this.secondaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.error,
  });
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceContainer;
  final Color card;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color secondary;
  final Color secondaryContainer;
  final Color outline;
  final Color outlineVariant;
  final Color error;
}
