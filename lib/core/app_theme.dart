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
  static const defaultPrimary = Color(0xFF2457C5);
  static const error = Color(0xFFB42318);
  static const errorContainer = Color(0xFFFEE4E2);

  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }

  static Color foreground(Color background) =>
      contrast(Colors.black, background) > contrast(Colors.white, background)
      ? Colors.black
      : Colors.white;

  static Color _readable(Color color, Color surface) {
    final target = foreground(surface);
    for (var step = 0; step <= 100; step++) {
      final candidate = Color.lerp(color, target, step / 100)!;
      if (contrast(candidate, surface) >= 4.5) return candidate;
    }
    return target;
  }

  static ThemeData build(SmartStockTheme selected, {Color? accent}) {
    final dark =
        selected == SmartStockTheme.dark ||
        selected == SmartStockTheme.blueSteel;
    final surface = dark ? const Color(0xFF1A2432) : Colors.white;
    final background = dark ? const Color(0xFF111820) : const Color(0xFFF5F7FA);
    final text = dark ? const Color(0xFFF4F7FB) : const Color(0xFF17212F);
    final muted = dark ? const Color(0xFFBCC8D8) : const Color(0xFF465469);
    final seed =
        accent ??
        switch (selected) {
          SmartStockTheme.defaultLight => defaultPrimary,
          SmartStockTheme.dark => const Color(0xFF9EBDFF),
          SmartStockTheme.blueSteel => const Color(0xFF88BEE8),
          SmartStockTheme.sageField => const Color(0xFF42633B),
        };
    final primary = _readable(seed, dark ? surface : background);
    final container = Color.lerp(surface, primary, .14)!;
    final outline = dark ? const Color(0xFF8B9AAD) : const Color(0xFF758296);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: foreground(primary),
          primaryContainer: container,
          onPrimaryContainer: text,
          secondary: primary,
          onSecondary: foreground(primary),
          secondaryContainer: container,
          onSecondaryContainer: text,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerLowest: surface,
          surfaceContainerLow: background,
          surfaceContainer: background,
          surfaceContainerHigh: container,
          surfaceContainerHighest: container,
          outline: outline,
          outlineVariant: outline,
          error: dark ? const Color(0xFFFFB4AB) : error,
          onError: dark ? const Color(0xFF601410) : Colors.white,
          errorContainer: dark ? const Color(0xFF51241F) : errorContainer,
          onErrorContainer: dark
              ? const Color(0xFFFFDAD6)
              : const Color(0xFF691B16),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: outline),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      extensions: [
        StockColors(
          healthy: dark ? const Color(0xFF8BD6A4) : const Color(0xFF21643A),
          warning: dark ? const Color(0xFFFFD18A) : const Color(0xFF805000),
        ),
      ],
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outline.withValues(alpha: .4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        errorMaxLines: 3,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(color: scheme.onSurface, width: 2)
                    : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? primary
                      : outline,
                  width: states.contains(WidgetState.focused) ? 2 : 1,
                ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: primary, width: 2)
                : null,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: primary, width: 2)
                : null,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: container,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium!.copyWith(color: text),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: container,
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: TextStyle(color: surface),
      ),
      dividerColor: outline.withValues(alpha: .4),
    );
  }
}

@immutable
class StockColors extends ThemeExtension<StockColors> {
  const StockColors({required this.healthy, required this.warning});
  final Color healthy;
  final Color warning;
  static const barcodeBackground = Colors.white;
  static const barcodeInk = Colors.black;
  static StockColors of(BuildContext context) =>
      Theme.of(context).extension<StockColors>() ??
      StockColors(
        healthy: Theme.of(context).colorScheme.primary,
        warning: Theme.of(context).colorScheme.error,
      );
  @override
  StockColors copyWith({Color? healthy, Color? warning}) => StockColors(
    healthy: healthy ?? this.healthy,
    warning: warning ?? this.warning,
  );
  @override
  StockColors lerp(covariant StockColors? other, double t) => other == null
      ? this
      : StockColors(
          healthy: Color.lerp(healthy, other.healthy, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
        );
}
