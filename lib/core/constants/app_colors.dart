import 'package:flutter/material.dart';

/// Central color palette for Archivix.
/// Use these constants everywhere instead of raw hex literals.
abstract class AppColors {
  // ─── Text ──────────────────────────────────────────────────────────────────
  /// Headings, titles, primary body text
  static const Color textPrimary = Color(0xFF1F2937);

  /// Secondary body text, dropdown labels
  static const Color textSecondary = Color(0xFF374151);

  /// Captions, metadata, helper text
  static const Color textMuted = Color(0xFF6B7280);

  /// Placeholders, disabled labels, faint hints
  static const Color textSubtle = Color(0xFF9CA3AF);

  // ─── Slate (papers, primary actions) ──────────────────────────────────────
  /// Primary action color — buttons, accents, borders on paper cards
  static const Color slatePrimary = Color(0xFF4A5568);

  /// Welcome banner background
  static const Color slateBanner = Color(0xFF4A5568); // same hue, aliased for intent clarity

  // ─── Borders & Backgrounds ────────────────────────────────────────────────
  /// Standard card / input border
  static const Color border = Color(0xFFD1D5DB);

  /// Light gray surface — metadata boxes, placeholders
  static const Color surfaceLight = Color(0xFFF3F4F6);

  /// Very light gray surface — discussion / comment placeholder areas
  static const Color surfaceFaint = Color(0xFFF9FAFB);

  /// Pure white surface — content cards
  static const Color surfaceWhite = Colors.white;

  // ─── Amber (posts / questions) ────────────────────────────────────────────
  /// Dark amber — post badge text, metadata icons, section accents
  static const Color amberDark = Color(0xFF92400E);

  /// Amber border — post card borders, badge borders
  static const Color amberBorder = Color(0xFFFCD34D);

  /// Amber surface — post badge bg, metadata card bg, email warning bg
  static const Color amberSurface = Color(0xFFFEF3C7);

  /// Warm amber tint — post card background in feed
  static const Color amberCardBg = Color(0xFFFFF9E6);

  /// Warm orange surface — document/PDF attachment card bg
  static const Color amberDocSurface = Color(0xFFFFF7ED);

  /// Warm orange border — document/PDF attachment card border
  static const Color amberDocBorder = Color(0xFFFED7AA);

  // ─── Status: Error ────────────────────────────────────────────────────────
  /// Error text, error icons
  static const Color errorDark = Color(0xFF991B1B);

  /// Error banner background
  static const Color errorSurface = Color(0xFFFEE2E2);

  /// Error banner border
  static const Color errorBorder = Color(0xFFEF4444);

  // ─── Status: Success ──────────────────────────────────────────────────────
  /// Success snackbar background — download complete, etc.
  static const Color success = Color(0xFF059669);
} 