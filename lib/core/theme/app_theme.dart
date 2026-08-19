import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette choices inspired by OpenHub-Store/Github-Store.
enum AppPalette {
  ocean,
  mint,
  purple,
  slate,
  amber,
  dynamic;

  String get label => switch (this) {
        AppPalette.ocean => 'Ocean',
        AppPalette.mint => 'Mint',
        AppPalette.purple => 'Purple',
        AppPalette.slate => 'Slate',
        AppPalette.amber => 'Amber',
        AppPalette.dynamic => 'Monet',
      };

  Color get seed => switch (this) {
        AppPalette.ocean => const Color(0xFF2A638A),
        AppPalette.mint => const Color(0xFF356859),
        AppPalette.purple => const Color(0xFF6750A4),
        AppPalette.slate => const Color(0xFF535E6C),
        AppPalette.amber => const Color(0xFF8B5000),
        // Unused: dynamic schemes come from the wallpaper, not a seed.
        AppPalette.dynamic => const Color(0xFF356859),
      };

  /// Swatch shown in palette picker (uses dark-mode primary for contrast).
  /// Placeholder for `dynamic` — the picker paints the live wallpaper color.
  Color get swatch => switch (this) {
        AppPalette.ocean => const Color(0xFF98CCF9),
        AppPalette.mint => const Color(0xFF9CD1BD),
        AppPalette.purple => const Color(0xFFCFBCFF),
        AppPalette.slate => const Color(0xFFB4C7D9),
        AppPalette.amber => const Color(0xFFFFB870),
        AppPalette.dynamic => const Color(0xFF9CD1BD),
      };
}

class AppTheme {
  AppTheme._();

  // Legacy constants kept const so existing `const` literal widgets compile.
  // These DO NOT react to palette changes — new code must use
  // Theme.of(context).colorScheme instead. Migration is incremental.
  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const Color primaryGreen = Color(0xFF63E6BE);
  @Deprecated('Use Theme.of(context).scaffoldBackgroundColor')
  static const Color backgroundBlack = Color(0xFF000000);
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainer')
  static const Color surfaceGrey = Color(0xFF1C1C1E);
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainerHigh')
  static const Color surfaceGreyLight = Color(0xFF2C2C2E);
  @Deprecated('Use Theme.of(context).colorScheme.onSurface')
  static const Color textWhite = Color(0xFFFFFFFF);
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant')
  static const Color textGrey = Color(0xFF8E8E93);

  /// Legacy dark theme — preserved for any non-consumer entrypoints.
  static final ThemeData darkTheme = buildTheme(
    palette: AppPalette.mint,
    brightness: Brightness.dark,
    amoled: true,
  );

  static ColorScheme _buildScheme(
    AppPalette palette,
    Brightness brightness,
  ) =>
      ColorScheme.fromSeed(
        seedColor: palette.seed,
        brightness: brightness,
      );

  static ThemeData buildTheme({
    required AppPalette palette,
    required Brightness brightness,
    bool amoled = false,
    ColorScheme? dynamicScheme,
  }) {
    var scheme = dynamicScheme ?? _buildScheme(palette, brightness);
    if (brightness == Brightness.dark && amoled) {
      scheme = scheme.copyWith(surface: const Color(0xFF000000));
    }

    final baseText = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    // Body/labels → Manrope. Display/headline → JetBrains Mono.
    final bodyText = GoogleFonts.manropeTextTheme(baseText);
    final textTheme = bodyText.copyWith(
      displayLarge: GoogleFonts.jetBrainsMono(textStyle: bodyText.displayLarge),
      displayMedium: GoogleFonts.jetBrainsMono(textStyle: bodyText.displayMedium),
      displaySmall: GoogleFonts.jetBrainsMono(textStyle: bodyText.displaySmall),
      headlineLarge: GoogleFonts.jetBrainsMono(textStyle: bodyText.headlineLarge),
      headlineMedium: GoogleFonts.jetBrainsMono(textStyle: bodyText.headlineMedium),
      headlineSmall: GoogleFonts.jetBrainsMono(textStyle: bodyText.headlineSmall),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        titleSpacing: 16,
        centerTitle: false,
        actionsPadding: const EdgeInsets.only(right: 8),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}
