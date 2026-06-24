import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';

abstract final class MockData {
  static const conversations = <Conversation>[
    Conversation(
      id: '1',
      name: 'Mario Rossi',
      preview: 'Perfetto, ci sentiamo domani allora ✓✓',
      timeLabel: '14:32',
      unreadCount: 2,
      avatarColor: Color(0xFF6B8E9B),
      isOnline: true,
    ),
    Conversation(
      id: '2',
      name: 'Team Alfred',
      preview: 'La nuova UI Flutter è in arrivo',
      timeLabel: '12:05',
      unreadCount: 0,
      avatarColor: Color(0xFF2D2926),
    ),
    Conversation(
      id: '3',
      name: 'Giulia Bianchi',
      preview: 'Hai visto il messaggio di ieri?',
      timeLabel: 'Ieri',
      unreadCount: 0,
      avatarColor: Color(0xFFC4A484),
      isOnline: true,
    ),
    Conversation(
      id: '4',
      name: 'Luca Verdi',
      preview: 'Grazie mille!',
      timeLabel: 'Lun',
      unreadCount: 0,
      avatarColor: Color(0xFF7B9E87),
    ),
    Conversation(
      id: '5',
      name: 'Supporto',
      preview: 'Ticket #42 aggiornato',
      timeLabel: 'Dom',
      unreadCount: 1,
      avatarColor: Color(0xFF8B7E9B),
    ),
  ];

  static const messagesByConversation = <String, List<ChatMessage>>{
    '1': [
      ChatMessage(
        id: 'm1',
        body: 'Ciao! Come va il progetto Alfred?',
        timeLabel: '14:10',
        isMine: false,
      ),
      ChatMessage(
        id: 'm2',
        body: 'Bene! Stiamo passando a Flutter + Supabase.',
        timeLabel: '14:15',
        isMine: true,
        status: MessageStatus.read,
      ),
      ChatMessage(
        id: 'm3',
        body: 'Ottimo. La UI mock è già su GitHub Pages?',
        timeLabel: '14:28',
        isMine: false,
      ),
      ChatMessage(
        id: 'm4',
        body: 'Sì, stesso URL di prima: /XmppTest/',
        timeLabel: '14:30',
        isMine: true,
        status: MessageStatus.delivered,
      ),
      ChatMessage(
        id: 'm5',
        body: 'Perfetto, ci sentiamo domani allora',
        timeLabel: '14:32',
        isMine: false,
      ),
    ],
    '2': [
      ChatMessage(
        id: 't1',
        body: 'Benvenuto nel canale Team Alfred.',
        timeLabel: '09:00',
        isMine: false,
      ),
      ChatMessage(
        id: 't2',
        body: 'La nuova UI Flutter è in arrivo — solo grafica per ora.',
        timeLabel: '12:05',
        isMine: false,
      ),
    ],
  };

  static List<ChatMessage> messagesFor(String conversationId) {
    return messagesByConversation[conversationId] ??
        const [
          ChatMessage(
            id: 'fallback',
            body: 'Nessun messaggio — dati mock.',
            timeLabel: '—',
            isMine: false,
          ),
        ];
  }
}
