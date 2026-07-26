// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'auth_identity.dart';

enum ComposeAddressKind { internalUsername, externalServer, invalid }

class ParsedComposeAddress {
  const ParsedComposeAddress({
    required this.kind,
    required this.normalized,
  });

  final ComposeAddressKind kind;
  final String normalized;

  bool get isInternal => kind == ComposeAddressKind.internalUsername;
  bool get isExternal => kind == ComposeAddressKind.externalServer;
}

/// Parsing minimo: username Alfred oppure forma email-like (`user@server`).
ParsedComposeAddress parseComposeAddress(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const ParsedComposeAddress(
      kind: ComposeAddressKind.invalid,
      normalized: '',
    );
  }

  if (normalized.contains('@')) {
    final emailLike = RegExp(r'^[a-z0-9._+-]+@[a-z0-9.-]+');
    if (emailLike.hasMatch(normalized)) {
      return ParsedComposeAddress(
        kind: ComposeAddressKind.externalServer,
        normalized: normalized,
      );
    }
    return ParsedComposeAddress(
      kind: ComposeAddressKind.invalid,
      normalized: normalized,
    );
  }

  if (AuthIdentity.isValidUsername(normalized)) {
    return ParsedComposeAddress(
      kind: ComposeAddressKind.internalUsername,
      normalized: normalized,
    );
  }

  return ParsedComposeAddress(
    kind: ComposeAddressKind.invalid,
    normalized: normalized,
  );
}

String? validateComposeAddressInput(String? raw) {
  final parsed = parseComposeAddress(raw ?? '');
  switch (parsed.kind) {
    case ComposeAddressKind.invalid:
      return 'Inserisci uno username o un indirizzo user@server';
    case ComposeAddressKind.externalServer:
      return 'Indirizzo esterno non ancora supportato';
    case ComposeAddressKind.internalUsername:
      return null;
  }
}
