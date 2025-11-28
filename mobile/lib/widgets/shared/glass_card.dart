import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../config/app_theme.dart';

/// Reusable Glassmorphism card widget that eliminates duplicated
/// ClipRRect + BackdropFilter + Container patterns across the app.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double? borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableTapEffect;

  const GlassCard({
    super.key,
    required this.child,
    this.blurSigma = 10,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.width,
    this.height,
    this.onTap,
    this.enableTapEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white.withValues(alpha: 0.05);
    final effectiveBorderColor = borderColor ?? Colors.white.withValues(alpha: 0.1);
    final effectiveRadius = borderRadius ?? AppTheme.radiusMedium;
    
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );

    // Wrap with tap handling if needed
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveRadius),
          splashColor: enableTapEffect 
              ? AppTheme.primaryElectricBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          highlightColor: enableTapEffect
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}

/// A GlassCard specifically styled as a text input container
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderColor: Colors.white.withValues(alpha: 0.2),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            validator: validator,
            autofocus: autofocus,
            focusNode: focusNode,
            textInputAction: textInputAction,
            onEditingComplete: onEditingComplete,
            style: AppTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: AppTheme.bodyMedium,
              hintStyle: AppTheme.bodyMedium.copyWith(
                color: AppTheme.secondaryText.withValues(alpha: 0.5),
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AppTheme.primaryElectricBlue)
                  : null,
              suffix: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped action button with gradient background
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final IconData? icon;
  final bool iconLeading;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.height = 56,
    this.gradient,
    this.boxShadow,
    this.icon,
    this.iconLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.primaryGradient,
        borderRadius: AppTheme.borderRadiusPill,
        boxShadow: boxShadow ?? AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: AppTheme.borderRadiusPill,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null && iconLeading) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTheme.labelLarge.copyWith(fontSize: 16),
                      ),
                      if (icon != null && !iconLeading) ...[
                        const SizedBox(width: 8),
                        Icon(icon, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A glass-styled button for secondary actions
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 56,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: height,
      borderColor: Colors.white.withValues(alpha: 0.2),
      onTap: isLoading ? null : onPressed,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 28, color: Colors.white),
                    const SizedBox(width: 12),
                  ],
                  Text(label, style: AppTheme.labelLarge),
                ],
              ),
      ),
    );
  }
}
