// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/message.dart';

/// Effetti home gruppo.
abstract class GroupHomeEffects {
  Future<void> loadHome();
}

/// Effetti conversazione gruppo.
abstract class GroupMessagesEffects {
  Future<void> loadMessages();

  void attachRealtime();

  void disposeRealtime();

  Future<void> runBroadcast();

  void onRealtimeMessage(ChatMessage message);
}
