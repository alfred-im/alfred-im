// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/message.dart';

class MessagingConversationState {
  List<ChatMessage> messages = [];
  String? error;
  bool hasMoreOlder = false;
  bool isLoadingOlder = false;
}
