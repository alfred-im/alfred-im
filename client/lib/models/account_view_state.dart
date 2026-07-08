import 'chat_peer.dart';

/// Cosa l'utente sta guardando nell'account in focus (inbox vs chat).
class AccountViewState {
  const AccountViewState({
    this.activePeer,
    this.showInboxOnMobile = true,
    this.groupChatOpen = false,
  });

  final ChatPeer? activePeer;
  final bool showInboxOnMobile;
  final bool groupChatOpen;

  AccountViewState clearConversation() => const AccountViewState();

  AccountViewState openChat(ChatPeer peer) => AccountViewState(
        activePeer: peer,
        showInboxOnMobile: false,
      );

  AccountViewState openGroupChat() => const AccountViewState(
        showInboxOnMobile: false,
        groupChatOpen: true,
      );

  AccountViewState backToInboxOnMobile() => AccountViewState(
        activePeer: activePeer,
        showInboxOnMobile: true,
      );

  AccountViewState backToGroupHome() => const AccountViewState(
        showInboxOnMobile: true,
        groupChatOpen: false,
      );

  AccountViewState mergeActivePeer(ChatPeer inboxRow) {
    if (activePeer?.profileId != inboxRow.profileId) return this;
    return AccountViewState(
      activePeer: activePeer!.mergeFromInbox(inboxRow),
      showInboxOnMobile: showInboxOnMobile,
    );
  }

  /// Evita chat aperte verso sé stessi (stato incoerente dopo switch account).
  AccountViewState sanitizedForAccount(String accountUserId) {
    if (activePeer?.profileId == accountUserId) {
      return const AccountViewState();
    }
    return this;
  }
}
