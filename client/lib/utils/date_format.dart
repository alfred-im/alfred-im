// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:intl/intl.dart';

const _italianWeekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

String formatMessageTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(local.year, local.month, local.day);

  if (messageDay == today) {
    return DateFormat.Hm().format(local);
  }
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return 'Ieri';
  }
  if (now.difference(local).inDays < 7) {
    return _italianWeekdays[local.weekday - 1];
  }
  return DateFormat('d/M/yy').format(local);
}

String formatConversationTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  return formatMessageTime(dateTime);
}

const _italianMonthsShort = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic',
];

/// Data di nascita / creazione profilo in italiano (es. «12 mar 2026»).
String formatProfileBirthDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day} ${_italianMonthsShort[local.month - 1]} ${local.year}';
}
