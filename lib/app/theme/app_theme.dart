import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_glass_theme.dart';
import 'app_text_styles.dart';

/// نظام «نهار البطولة» المبني على Material 3 Expressive لأندرويد.
///
/// الأسطح التشغيلية صلبة. لا يضيف الـTheme ضبابية لأي Card أو Dialog؛ الزجاج
/// الوظيفي يظل قرارًا صريحًا في شريط التنقل أو أدوات المعاينة فقط.
abstract final class AppTheme {
  static const ColorScheme _daylightScheme = ColorScheme.light(
    primary: AppColors.actionPrimary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.actionContainer,
    onPrimaryContainer: AppColors.actionStrong,
    secondary: AppColors.info,
    onSecondary: AppColors.textOnPrimary,
    secondaryContainer: AppColors.infoContainer,
    onSecondaryContainer: AppColors.infoDark,
    tertiary: AppColors.tactical,
    onTertiary: AppColors.textOnPrimary,
    tertiaryContainer: AppColors.tacticalContainer,
    onTertiaryContainer: AppColors.tacticalDark,
    error: AppColors.error,
    onError: AppColors.textOnPrimary,
    errorContainer: AppColors.errorSurface,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceDim: AppColors.backgroundDeep,
    surfaceBright: AppColors.surfaceRaised,
    surfaceContainerLowest: AppColors.backgroundDeep,
    surfaceContainerLow: AppColors.surfaceSunken,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceRaised,
    surfaceContainerHighest: AppColors.backgroundLight,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.surfaceBorderStrong,
    outlineVariant: AppColors.surfaceBorder,
    shadow: AppColors.black,
    scrim: Color(0x5217202C),
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.chalk,
    inversePrimary: AppColors.actionLight,
    surfaceTint: Colors.transparent,
  );

  static ThemeData get lightTheme {
    final textTheme = AppTextStyles.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _daylightScheme,
      // The app-level daylight backdrop owns the single static gradient/glow.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      focusColor: AppColors.actionPrimary.withValues(alpha: 0.18),
      hoverColor: AppColors.actionPrimary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      disabledColor: AppColors.textMuted.withValues(alpha: 0.45),
      extensions: const <ThemeExtension<dynamic>>[AppGlassTheme.daylight],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),

      // ── System & app bars ──
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: AppColors.background,
        ),
        titleTextStyle: AppTextStyles.headlineSmall,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: AppDimensions.iconMd,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: AppDimensions.iconMd,
        ),
      ),

      // ── Solid surfaces ──
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.cardElevation,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: const BorderSide(
            color: AppColors.surfaceBorder,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.headlineSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        modalBackgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x5217202C),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.surfaceBorderStrong,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
      ),

      // ── Primary & secondary actions ──
      filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(AppDimensions.minTouchTarget, AppDimensions.buttonHeightMd),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMuted.withValues(alpha: 0.55);
            }
            return AppColors.textPrimary;
          }),
          overlayColor: WidgetStatePropertyAll<Color>(
            AppColors.actionPrimary.withValues(alpha: 0.1),
          ),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: AppColors.surfaceBorder);
            }
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(
                color: AppColors.actionPrimary,
                width: 1.5,
              );
            }
            return const BorderSide(color: AppColors.surfaceBorderStrong);
          }),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.buttonText.copyWith(color: AppColors.textPrimary),
          ),
          animationDuration: const Duration(
            milliseconds: AppDimensions.animFast,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(AppDimensions.minTouchTarget, AppDimensions.minTouchTarget),
          ),
          foregroundColor: const WidgetStatePropertyAll<Color>(
            AppColors.actionPrimary,
          ),
          overlayColor: WidgetStatePropertyAll<Color>(
            AppColors.actionPrimary.withValues(alpha: 0.1),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            AppTextStyles.labelLarge,
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          animationDuration: const Duration(
            milliseconds: AppDimensions.animFast,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size.square(AppDimensions.minTouchTarget),
          ),
          foregroundColor: const WidgetStatePropertyAll<Color>(
            AppColors.textPrimary,
          ),
          overlayColor: WidgetStatePropertyAll<Color>(
            AppColors.actionPrimary.withValues(alpha: 0.1),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        ),
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: 14,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        labelStyle: AppTextStyles.bodyMedium,
        floatingLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.actionPrimary,
        ),
        helperStyle: AppTextStyles.bodySmall,
        errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
        border: _inputBorder(AppColors.surfaceBorderStrong),
        enabledBorder: _inputBorder(AppColors.surfaceBorderStrong),
        disabledBorder: _inputBorder(
          AppColors.surfaceBorder.withValues(alpha: 0.55),
        ),
        focusedBorder: _inputBorder(AppColors.actionPrimary, width: 2),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 2),
      ),

      // ── Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        height: AppDimensions.bottomNavHeight,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.actionSurface,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.actionPrimary
                : AppColors.textMuted,
            size: AppDimensions.iconMd,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return AppTextStyles.labelSmall.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.actionPrimary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        enableFeedback: true,
        selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.actionPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Dense data & status components ──
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.titleMedium,
        subtitleTextStyle: AppTextStyles.bodySmall,
        minTileHeight: AppDimensions.minTouchTarget,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSunken,
        selectedColor: AppColors.actionSurface,
        disabledColor: AppColors.surfaceSunken.withValues(alpha: 0.55),
        checkmarkColor: AppColors.actionPrimary,
        side: const BorderSide(color: AppColors.surfaceBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: AppTextStyles.labelMedium,
        secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll<Color>(
          AppColors.surfaceSunken,
        ),
        dataRowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        headingTextStyle: AppTextStyles.labelMedium,
        dataTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        dividerThickness: 1,
        horizontalMargin: AppDimensions.md,
        columnSpacing: AppDimensions.md,
        headingRowHeight: 48,
        dataRowMinHeight: 48,
      ),

      // ── Feedback & selection ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        actionTextColor: AppColors.actionPrimary,
        disabledActionTextColor: AppColors.textMuted,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppDimensions.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.actionPrimary,
        linearTrackColor: AppColors.surfaceBorder,
        circularTrackColor: AppColors.surfaceBorder,
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.space1),
        ),
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.actionPrimary;
          }
          return null;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(
          AppColors.textOnPrimary,
        ),
        side: const BorderSide(color: AppColors.surfaceBorderStrong, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.actionPrimary
              : AppColors.surfaceBorderStrong;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.textOnPrimary
              : AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.actionPrimary
              : AppColors.surfaceBorder;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          border: Border.all(color: AppColors.textPrimary),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        textStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.chalk),
      ),
    );
  }

  static ButtonStyle get _primaryButtonStyle => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size(AppDimensions.minTouchTarget, AppDimensions.buttonHeightMd),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.surfaceBorder;
      }
      if (states.contains(WidgetState.pressed)) return AppColors.actionStrong;
      return AppColors.actionPrimary;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
      return AppColors.textOnPrimary;
    }),
    overlayColor: WidgetStatePropertyAll<Color>(
      AppColors.textOnPrimary.withValues(alpha: 0.08),
    ),
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(AppTextStyles.buttonText),
    animationDuration: const Duration(milliseconds: AppDimensions.animFast),
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
