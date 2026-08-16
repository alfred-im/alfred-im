// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

/// Riga `instance_config` esposta a owner via `list_instance_config`.
class InstanceConfigEntry {
  const InstanceConfigEntry({
    required this.key,
    required this.value,
    this.updatedAt,
  });

  factory InstanceConfigEntry.fromRow(Map<String, dynamic> row) {
    final rawValue = row['value'];
    return InstanceConfigEntry(
      key: row['key'] as String,
      value: _valueToEditableString(rawValue),
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  final String key;
  final String value;
  final DateTime? updatedAt;

  static String _valueToEditableString(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    return const JsonEncoder.withIndent('  ').convert(raw);
  }

  dynamic parseValueForSave() {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }
}
