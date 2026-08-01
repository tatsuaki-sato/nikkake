import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// 画面をまたいで使う小さな部品。
/// 3実装(RN/Flutter/KMP)で見た目を揃える必要があるので、
/// 余白・角丸・色はここに集約して各画面で個別に決めない。

class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

/// '#RRGGBB' 形式の文字列をColorへ。DBに色をhexで保存しているため
Color hexToColor(String hex, {Color fallback = AppColors.darkPrimary}) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color ?? AppColors.darkSurface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;

  const SectionTitle(this.text, {super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: Spacing.md),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.darkPrimary, Colors.white, null),
      AppButtonVariant.secondary => (
          AppColors.darkSurfaceElevated,
          AppColors.darkTextPrimary,
          AppColors.darkBorder
        ),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.darkPrimaryLight, null),
      AppButtonVariant.danger => (Colors.transparent, AppColors.darkError, AppColors.darkError),
    };

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: 48,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg,
            disabledForegroundColor: fg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              side: border == null ? BorderSide.none : BorderSide(color: border),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: Spacing.md),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.darkTextSecondary, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: Spacing.lg), action!],
        ],
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  final String? message;

  const ErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Text(
        message!,
        key: const Key('error-message'),
        style: const TextStyle(color: AppColors.darkError, fontSize: 14),
      ),
    );
  }
}

class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkPrimary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? AppColors.darkPrimary : AppColors.darkBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.darkTextPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 削除など取り返しのつかない操作の確認
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '削除',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.darkSurfaceElevated,
      title: Text(title, style: const TextStyle(color: AppColors.darkTextPrimary)),
      content: Text(message, style: const TextStyle(color: AppColors.darkTextSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          key: const Key('confirm-action'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel, style: const TextStyle(color: AppColors.darkError)),
        ),
      ],
    ),
  );

  return result ?? false;
}
