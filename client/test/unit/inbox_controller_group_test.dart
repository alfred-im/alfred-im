import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/providers/inbox_controller.dart';

import '../support/fake_messaging_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InboxController group accounts', () {
    test('enableInboxLoads false skips fetchInbox', () async {
      final inboxService = FakeInboxService();
      final controller = InboxController(
        userId: 'group-account-id',
        inboxService: inboxService,
        enableRealtime: false,
        enableInboxLoads: false,
      );

      for (var i = 0; i < 50 && controller.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(inboxService.fetchInboxCalls, 0);
      expect(controller.peers, isEmpty);
      expect(controller.isLoading, isFalse);

      await controller.load();
      expect(inboxService.fetchInboxCalls, 0);

      controller.dispose();
    });
  });
}
