// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Canonical voice note format (WebM + Opus) — contract for client and storage.
abstract final class VoiceConfig {
  static const canonicalMime = 'audio/webm';
  static const fileExtension = 'webm';
  static const maxDurationSeconds = 600;
  static const maxBytes = 15 * 1024 * 1024;
  static const minDurationMs = 1000;
  static const lockSwipeThresholdPx = 48;
  static const cancelSwipeThresholdPx = 72;
}
