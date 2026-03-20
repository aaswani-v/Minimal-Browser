/// Shared glassmorphism container widget.
///
/// Provides a frosted-glass effect with optional adaptive coloring based
/// on the active tab's dominant color. Used throughout the app for cards,
/// nav bars, and list items to create the "Nothing" design language.
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassWidget extends StatelessWidget {
  /// The child widget rendered inside the glass container.
  final Widget child;

  /// The border radius of the glass container.
  final BorderRadius borderRadius;

  /// Optional accent color derived from the active tab's favicon.
  /// When provided, the glass container uses a gradient tint.
  final Color? adaptiveColor;

  /// When true, uses a more transparent style suited for the bottom nav bar.
  final bool useFigmaNavStyle;

  const GlassWidget({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.adaptiveColor,
    this.useFigmaNavStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = adaptiveColor;
    // Nav bar uses a stronger blur for a more polished look.
    final blurSigma = useFigmaNavStyle ? 64.0 : 48.0;

    // Determine the decoration based on the style context.
    final decoration = useFigmaNavStyle
        ? BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: borderRadius,
          )
        : color != null
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
              )
            // Default style: Figma specs — fill #706C6C @ 10%, stroke #FFFFFF @ 18%
            : BoxDecoration(
                color: const Color(0xFF706C6C).withOpacity(0.10),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
              );

    return ClipRRect(
      borderRadius: borderRadius,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}
