import 'chat_peer.dart';

/// Cosa l'utente sta guardando nell'account in focus (inbox vs chat).
class AccountViewState {
  const AccountViewState({
    this.activePeer,
    this.showInboxOnMobile = true,
  });

  final ChatPeer? activePeer;
  final bool showInboxOnMobile;

  AccountViewState clearConversation() => const AccountViewState();

  AccountViewState openChat(ChatPeer peer) => AccountViewState(
        activePeer: peer,
        showInboxOnMobile: false,
      );

  AccountViewState backToInboxOnMobile() => AccountViewState(
        activePeer: activePeer,
        showInboxOnMobile: true,
      );

  AccountViewState mergeActivePeer(ChatPeer inboxRow) {
    if (activePeer?.profileId != inboxRow.profileId) return this;
    return AccountViewState(
      activePeer: activePeer!.mergeFromInbox(inboxRow),
      showInboxOnMobile: showInboxOnMobile,
    );
  }
}
