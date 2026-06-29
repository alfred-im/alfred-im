import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/providers/inbox_controller.dart';
import 'package:alfred_client/services/inbox_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AuthStub extends ChangeNotifier {
  _AuthStub(this._userId);

  String? _userId;
  bool sessionReady = true;

  String? get userId => _userId;

  void setUser(String? userId) {
    _userId = userId;
    notifyListeners();
  }
}

class _ImmediateInboxService extends InboxService {
  _ImmediateInboxService()
      : super(
          SupabaseClient(
            'http://127.0.0.1',
            'test-anon-key',
            authOptions: const FlutterAuthClientOptions(
              localStorage: EmptyLocalStorage(),
              autoRefreshToken: false,
            ),
          ),
        );

  @override
  Future<List<ChatPeer>> fetchInbox() async => [];
}

void main() {
  testWidgets(
    'ListenableProxyProvider with noop dispose keeps InboxController alive on focus switch',
    (tester) async {
      final auth = _AuthStub('user-a');
      final inboxA = InboxController(
        userId: 'user-a',
        inboxService: _ImmediateInboxService(),
        enableRealtime: false,
      );
      final inboxB = InboxController(
        userId: 'user-b',
        inboxService: _ImmediateInboxService(),
        enableRealtime: false,
      );

      InboxController? currentInbox() {
        return switch (auth.userId) {
          'user-a' => inboxA,
          'user-b' => inboxB,
          _ => null,
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<_AuthStub>.value(
            value: auth,
            child: ListenableProxyProvider<_AuthStub, InboxController?>(
              create: (_) => null,
              update: (_, auth, _) => currentInbox(),
              dispose: (context, inbox) {
                // Come main.dart: lifecycle in AccountSession.close().
              },
              child: Builder(
                builder: (context) {
                  final inbox = context.watch<InboxController?>();
                  return Text(inbox?.userId ?? 'none');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('user-a'), findsOneWidget);

      auth.setUser('user-b');
      await tester.pump();
      expect(find.text('user-b'), findsOneWidget);

      auth.setUser('user-a');
      await tester.pump();
      expect(find.text('user-a'), findsOneWidget);

      // Regression: inbox A non deve essere disposed al cambio focus.
      expect(() => inboxA.notifyListeners(), returnsNormally);

      inboxA.dispose();
      inboxB.dispose();
    },
  );
}
