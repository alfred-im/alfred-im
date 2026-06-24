import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alfred_client/models/conversation.dart';
import 'package:alfred_client/providers/conversations_controller.dart';
import 'package:alfred_client/services/conversation_service.dart';

class _AuthModel extends ChangeNotifier {
  bool sessionReady = true;
  String? userId = 'user-1';
}

class _ImmediateConversationService extends ConversationService {
  @override
  Future<List<Conversation>> fetchConversations() async {
    return const [
      Conversation(
        id: 'c1',
        name: 'Alice',
        preview: 'Ciao',
        timeLabel: '12:00',
        unreadCount: 0,
        avatarColor: Color(0xFF000000),
      ),
    ];
  }
}

void main() {
  testWidgets(
    'ChangeNotifierProxyProvider rebuilds when ConversationsController notifies',
    (tester) async {
      final auth = _AuthModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<_AuthModel>.value(
            value: auth,
            child: ChangeNotifierProxyProvider<_AuthModel,
                ConversationsController?>(
              create: (_) => null,
              update: (_, auth, previous) {
                if (!auth.sessionReady || auth.userId == null) return null;
                return ConversationsController(
                  userId: auth.userId!,
                  conversationService: _ImmediateConversationService(),
                  enableRealtime: false,
                );
              },
              child: Builder(
                builder: (context) {
                  final conversations =
                      context.watch<ConversationsController?>();
                  if (conversations == null || conversations.isLoading) {
                    return const Text('loading');
                  }
                  return Text('ready:${conversations.conversations.length}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ready:1'), findsOneWidget);
    },
  );
}
