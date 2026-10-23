import 'package:flutter/material.dart';

/// Семантические цвета поверх [ColorScheme] (success / warning).
///
/// В Material 3 нет готовых ролей «успех» / «предупреждение» — берём их из
/// отдельных [ColorScheme.fromSeed] на Material-палитре (green / orange).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static AppSemanticColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppSemanticColors>();
    assert(ext != null, 'AppSemanticColors missing from ThemeData.extensions');
    return ext!;
  }

  static AppSemanticColors forBrightness(Brightness brightness) {
    final success = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: brightness,
    );
    final warning = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: brightness,
    );
    return AppSemanticColors(
      success: success.primary,
      onSuccess: success.onPrimary,
      successContainer: success.primaryContainer,
      onSuccessContainer: success.onPrimaryContainer,
      warning: warning.primary,
      onWarning: warning.onPrimary,
      warningContainer: warning.primaryContainer,
      onWarningContainer: warning.onPrimaryContainer,
    );
  }

  static AppSemanticColors light() => forBrightness(Brightness.light);

  static AppSemanticColors dark() => forBrightness(Brightness.dark);

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

/// Единая Material 3 тема приложения.
abstract final class AppTheme {
  /// Seed из Material Blue (раньше был литерал `0xFF1565C0` = Blue 800).
  static final Color brandSeed = Colors.blue.shade800;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: brandSeed,
      brightness: brightness,
    );
    // Дефолтный M3 dark почти чёрный — чуть поднимаем surface.
    if (brightness == Brightness.dark) {
      colorScheme = colorScheme.copyWith(
        surface: Color.lerp(colorScheme.surface, Colors.white, 0.08)!,
        surfaceContainerLowest:
            Color.lerp(colorScheme.surfaceContainerLowest, Colors.white, 0.06)!,
        surfaceContainerLow:
            Color.lerp(colorScheme.surfaceContainerLow, Colors.white, 0.07)!,
        surfaceContainer:
            Color.lerp(colorScheme.surfaceContainer, Colors.white, 0.08)!,
        surfaceContainerHigh:
            Color.lerp(colorScheme.surfaceContainerHigh, Colors.white, 0.09)!,
      );
    }
    final semantic = AppSemanticColors.forBrightness(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 40),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[semantic],
    );
  }
}
