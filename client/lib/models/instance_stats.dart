// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Statistiche istanza (RPC `get_instance_stats`, solo owner).
class InstanceStats {
  const InstanceStats({
    required this.totalUserAccounts,
    required this.totalGroups,
    required this.disabledAccounts,
    required this.totalMessages,
    required this.messagesLast7Days,
    required this.activeAccounts30d,
  });

  factory InstanceStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return InstanceStats(
      totalUserAccounts: readInt('total_user_accounts'),
      totalGroups: readInt('total_groups'),
      disabledAccounts: readInt('disabled_accounts'),
      totalMessages: readInt('total_messages'),
      messagesLast7Days: readInt('messages_last_7_days'),
      activeAccounts30d: readInt('active_accounts_30d'),
    );
  }

  final int totalUserAccounts;
  final int totalGroups;
  final int disabledAccounts;
  final int totalMessages;
  final int messagesLast7Days;
  final int activeAccounts30d;
}
