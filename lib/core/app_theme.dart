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
  // Approved Stitch "Executive Precision" palette.
  static const defaultPrimary = Color(0xFF112338);
  static const canvas = Color(0xFFEEF2F6);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF8FAFC);
  static const borderSubtle = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const info = Color(0xFF2563EB);
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

  static Color _readableAcross(Color color, List<Color> surfaces) {
    final blackScore = surfaces
        .map((surface) => contrast(Colors.black, surface))
        .reduce((a, b) => a < b ? a : b);
    final whiteScore = surfaces
        .map((surface) => contrast(Colors.white, surface))
        .reduce((a, b) => a < b ? a : b);
    final target = blackScore >= whiteScore ? Colors.black : Colors.white;

    for (var step = 0; step <= 100; step++) {
      final candidate = Color.lerp(color, target, step / 100)!;
      if (surfaces.every((surface) => contrast(candidate, surface) >= 4.5)) {
        return candidate;
      }
    }
    return target;
  }

  static ThemeData build(SmartStockTheme selected, {Color? accent}) {
    final dark =
        selected == SmartStockTheme.dark ||
        selected == SmartStockTheme.blueSteel;

    final surface = dark ? const Color(0xFF172231) : surfaceCard;
    final background = dark
        ? const Color(0xFF0F1722)
        : selected == SmartStockTheme.sageField
        ? const Color(0xFFF0F4EF)
        : canvas;
    final text = dark ? const Color(0xFFF4F7FB) : textPrimary;
    final muted = dark ? const Color(0xFFB8C5D6) : textSecondary;

    final seed =
        accent ??
        switch (selected) {
          SmartStockTheme.defaultLight => defaultPrimary,
          SmartStockTheme.dark => const Color(0xFFA9C4E7),
          SmartStockTheme.blueSteel => const Color(0xFF8FC4EC),
          SmartStockTheme.sageField => const Color(0xFF365E48),
        };
    final primary = _readableAcross(seed, [background, surface]);
    final primaryContainer = dark
        ? Color.lerp(surface, primary, .22)!
        : Color.lerp(surface, primary, .10)!;

    // `outline` remains accessible for legacy components/tests. Visual card and
    // field borders use `outlineVariant`, which carries the approved hairline.
    final outline = dark ? const Color(0xFFA8B5C6) : textSecondary;
    final outlineVariant = dark
        ? const Color(0xFF344256)
        : borderSubtle;
    final containerLow = dark
        ? const Color(0xFF131E2B)
        : surfaceSubtle;
    final containerHigh = dark
        ? const Color(0xFF223147)
        : const Color(0xFFF1F5F9);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: foreground(primary),
          primaryContainer: primaryContainer,
          onPrimaryContainer: foreground(primaryContainer),
          secondary: dark ? const Color(0xFF9BB9FF) : info,
          onSecondary: dark ? const Color(0xFF102448) : Colors.white,
          secondaryContainer: containerHigh,
          onSecondaryContainer: text,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerLowest: surface,
          surfaceContainerLow: containerLow,
          surfaceContainer: background,
          surfaceContainerHigh: containerHigh,
          surfaceContainerHighest: containerHigh,
          outline: outline,
          outlineVariant: outlineVariant,
          error: dark ? const Color(0xFFFFB4AB) : error,
          onError: dark ? const Color(0xFF601410) : Colors.white,
          errorContainer: dark ? const Color(0xFF51241F) : errorContainer,
          onErrorContainer: dark
              ? const Color(0xFFFFDAD6)
              : const Color(0xFF691B16),
        );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontSize: 30,
        height: 38 / 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 17,
        height: 22 / 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -.15,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -.05,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        height: 18 / 13,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: .1,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        height: 16 / 13,
        fontWeight: FontWeight.w600,
        letterSpacing: .1,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .2,
      ),
    ).apply(bodyColor: text, displayColor: text);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: outlineVariant),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      textTheme: textTheme,
      extensions: [
        StockColors(
          // Slightly deeper than Stitch's display colors so standalone text
          // continues to meet the app's existing WCAG contrast tests.
          healthy: dark ? const Color(0xFF82D6A3) : const Color(0xFF047857),
          warning: dark ? const Color(0xFFFFCF85) : const Color(0xFF92400E),
        ),
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        errorMaxLines: 3,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: .78)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: scheme.onSurface, width: 2)
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          side: BorderSide(color: outlineVariant),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          foregroundColor: text,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? primary
                  : outlineVariant,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: primary, width: 2)
                : null,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: primary, width: 2)
                : null,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface.withValues(alpha: .97),
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? dark
                      ? text
                      : primary
                : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? dark
                      ? text
                      : primary
                : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primaryContainer,
        selectedIconTheme: IconThemeData(color: foreground(primaryContainer)),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary,
        side: BorderSide(color: outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: foreground(primary),
        ),
      ),
      dividerColor: outlineVariant,
      dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: TextStyle(color: surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
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
