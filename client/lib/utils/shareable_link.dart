// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/profile_summary.dart';
import '../utils/auth_identity.dart';
import 'compose_address.dart';

/// Destinazione di un link condivisibile (`#indirizzo` o `#indirizzo/chat`).
enum ShareableLinkKind { profile, chat }

class ShareableLinkTarget {
  const ShareableLinkTarget({
    required this.address,
    required this.kind,
  });

  /// Indirizzo normalizzato (`username` o `username@server`).
  final String address;
  final ShareableLinkKind kind;
}

/// Risultato parsing indirizzo per risoluzione locale.
class ShareableAddressResolution {
  const ShareableAddressResolution({
    required this.normalizedAddress,
    required this.localUsername,
    this.isLocalInstance = true,
  });

  final String normalizedAddress;
  final String localUsername;

  /// `true` se `@server` coincide con l'istanza corrente o bare username.
  final bool isLocalInstance;
}

/// Legge il fragment corrente (senza `#`), o `null` se assente.
ShareableLinkTarget? parseShareableFragment(String? fragment) {
  var raw = (fragment ?? '').trim();
  if (raw.startsWith('/')) {
    raw = raw.substring(1);
  }
  if (raw.isEmpty) return null;

  if (raw.startsWith('push-chat/')) return null;

  var kind = ShareableLinkKind.profile;
  const chatSuffix = '/chat';
  if (raw.endsWith(chatSuffix)) {
    kind = ShareableLinkKind.chat;
    raw = raw.substring(0, raw.length - chatSuffix.length);
  }

  final resolution = resolveShareableAddress(raw);
  if (resolution == null) return null;

  return ShareableLinkTarget(
    address: resolution.normalizedAddress,
    kind: kind,
  );
}

/// Normalizza e verifica se l'indirizzo è valido per link/share.
ShareableAddressResolution? resolveShareableAddress(String raw) {
  final parsed = parseComposeAddress(raw);
  switch (parsed.kind) {
    case ComposeAddressKind.invalid:
      return null;
    case ComposeAddressKind.internalUsername:
      return ShareableAddressResolution(
        normalizedAddress: parsed.normalized,
        localUsername: parsed.normalized,
        isLocalInstance: true,
      );
    case ComposeAddressKind.externalServer:
      final at = parsed.normalized.lastIndexOf('@');
      if (at <= 0) return null;
      final username = parsed.normalized.substring(0, at);
      final server = parsed.normalized.substring(at + 1);
      if (!AuthIdentity.isValidUsername(username)) {
        return null;
      }
      final isLocal = server == AppConfig.imServerId.toLowerCase();
      return ShareableAddressResolution(
        normalizedAddress: parsed.normalized,
        localUsername: username,
        isLocalInstance: isLocal,
      );
  }
}

/// Indirizzo canonico «pulito» per link profilo (preferisce `username` senza server).
String canonicalShareableAddress(ProfileSummary profile) {
  final username = profile.username?.trim().toLowerCase();
  if (username == null || username.isEmpty) {
    final address = profile.address?.trim().toLowerCase();
    if (address == null || address.isEmpty) {
      throw StateError('Profilo senza indirizzo condivisibile');
    }
    return address;
  }
  return username;
}

/// URL completo con fragment `#indirizzo` (profilo).
String buildShareableProfileUrl(String canonicalAddress) {
  final base = Uri.base;
  final path = base.path.isEmpty
      ? '/'
      : (base.path.endsWith('/') ? base.path : '${base.path}/');
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
    fragment: canonicalAddress,
  ).toString();
}

extension ProfileSummaryShareable on ProfileSummary {
  String get shareableProfileUrl =>
      buildShareableProfileUrl(canonicalShareableAddress(this));
}

/// Username dal manifest se [profile] non lo espone ancora in UI.
ProfileSummary profileForSharing(
  ProfileSummary profile, {
  String? fallbackUsername,
}) {
  if (profile.hasUsername) return profile;
  final username = fallbackUsername?.trim().toLowerCase();
  if (username == null || username.isEmpty) return profile;
  return profile.copyWith(username: username, address: username);
}

/// Invocazione share di sistema sostituibile nei test.
@visibleForTesting
Future<void> Function(ShareParams params)? shareParamsInvokerForTest;

/// Apre il foglio Condividi di sistema con il link profilo `#indirizzo`.
Future<void> shareShareableProfileLink(
  BuildContext context,
  ProfileSummary profile, {
  String? shareTitle,
  Rect? sharePositionOrigin,
}) async {
  if (!profile.hasUsername && !profile.hasAddress) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Questo profilo non ha un indirizzo condivisibile'),
      ),
    );
    return;
  }

  final url = profile.shareableProfileUrl;
  final params = ShareParams(
    text: url,
    subject: shareTitle ?? profile.displayName,
    sharePositionOrigin: sharePositionOrigin,
  );

  try {
    if (shareParamsInvokerForTest != null) {
      await shareParamsInvokerForTest!(params);
      return;
    }
    await SharePlus.instance.share(params);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Condivisione non disponibile')),
    );
  }
}
