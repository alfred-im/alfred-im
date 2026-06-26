import 'package:flutter/material.dart';

/// Colore avatar deterministico da id (stesso utente → stesso colore).
Color avatarColorForId(String id) {
  final hash = id.codeUnits.fold<int>(0, (a, b) => a + b);
  const palette = [
    Color(0xFF6B7FD7),
    Color(0xFFE67E22),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF2D2926),
    Color(0xFF16A085),
  ];
  return palette[hash % palette.length];
}

String avatarInitial(String name, {String fallback = '?'}) {
  if (name.isEmpty) return fallback;
  return name[0].toUpperCase();
}
