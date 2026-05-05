import 'package:flutter/material.dart';

/// Single source of truth for colors, spacing, and type scale.
abstract final class Tokens {
  // Backgrounds
  static const surface = Color(0xFF121212);
  static const card = Color(0xFF1E1E1E);
  static const elevated = Color(0xFF2D2D2D);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);
  static const textMuted = Color(0xFF757575);

  // Node kinds
  static const component = Color(0xFF4CAF50);
  static const event = Color(0xFFFF9800);
  static const dataEvent = Color(0xFFFFB74D);
  static const dependency = Color(0xFF9E9E9E);
  static const system = Color(0xFF2196F3);
  static const lifecycle = Color(0xFF9C27B0);

  // Edge kinds
  static const edgeReactsTo = Color(0xFF66BB6A);
  static const edgeInteractsWith = Color(0xFF42A5F5);
  static const edgeLifecycle = Color(0xFFAB47BC);
  static const edgeDefault = Color(0xFF757575);

  // Selection / highlighting
  static const selected = Color(0xFFFFEB3B);
  static const selectionBorder = Color(0xFFFFC107);

  // Log levels
  static const logVerbose = Color(0xFF9E9E9E);
  static const logDebug = Color(0xFF2196F3);
  static const logInfo = Color(0xFF4CAF50);
  static const logWarning = Color(0xFFFF9800);
  static const logError = Color(0xFFF44336);
  static const logFatal = Color(0xFF9C27B0);

  // Connection
  static const connConnected = Color(0xFF4CAF50);
  static const connConnecting = Color(0xFFFF9800);
  static const connDisconnected = Color(0xFF9E9E9E);
  static const connStale = Color(0xFFFFB74D);
  static const connError = Color(0xFFF44336);

  // Spacing scale
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 24.0;

  // Type
  static const fontMono = 'monospace';
}
