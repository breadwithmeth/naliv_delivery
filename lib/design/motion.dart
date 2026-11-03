/// Motion tokens: how long and how fast interface state changes move.
///
/// Every animation in the app runs on transform, opacity or colour only and takes its
/// duration from [AppMotion.of], which collapses to [Duration.zero] when the platform asks
/// to reduce animations (`MediaQuery.disableAnimationsOf`).
library;

import 'package:flutter/material.dart';

abstract final class AppMotion {
  /// A surface sinking under the finger.
  static const Duration pressDown = Duration(milliseconds: 100);

  /// A surface returning after the finger lifts.
  static const Duration pressUp = Duration(milliseconds: 160);

  /// A changing number sliding to its next value.
  static const Duration count = Duration(milliseconds: 160);

  /// Colour fills and text colours reacting to selection.
  static const Duration state = Duration(milliseconds: 180);

  /// Controls cross-fading into a different control.
  static const Duration swap = Duration(milliseconds: 180);

  /// A toggle that pops, for example the favourite heart.
  static const Duration pop = Duration(milliseconds: 220);

  /// A thumb sliding between segments.
  static const Duration slide = Duration(milliseconds: 220);

  /// Network artwork fading in after its first decode.
  static const Duration image = Duration(milliseconds: 200);

  /// A badge bumping when its count grows.
  static const Duration bump = Duration(milliseconds: 280);

  /// Confident deceleration for everything that arrives or moves.
  static const Curve out = Curves.easeOutCubic;

  /// Faster acceleration for whatever leaves.
  static const Curve leave = Curves.easeInCubic;

  /// Small overshoot, only for tiny "pop" feedback.
  static const Curve overshoot = Curves.easeOutBack;

  /// Whether the platform asked to reduce animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or [Duration.zero] when animations are disabled.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
