import '../models/message.dart';
import '../models/profile_summary.dart';

/// Etichetta leggibile per l'autore del contenuto (nome, non @username).
String authorLabelForProfile(ProfileSummary profile) {
  final name = profile.displayName.trim();
  if (name.isNotEmpty) return name;
  if (profile.hasUsername) return profile.username!;
  return 'Partecipante';
}

/// Arricchisce [message] con nome e avatar dell'autore del contenuto.
ChatMessage enrichMessageAuthor({
  required ChatMessage message,
  required Map<String, ProfileSummary> profilesById,
  required String currentUserId,
}) {
  final authorId = message.contentAuthorId ?? message.authorId;
  if (authorId == null) return message;

  if (authorId == currentUserId) {
    return message.copyWith(
      authorDisplayName: 'Tu',
      authorProfileId: currentUserId,
    );
  }

  final profile = profilesById[authorId];
  if (profile == null) return message;

  return message.copyWith(
    authorDisplayName: authorLabelForProfile(profile),
    authorAvatarUrl: profile.avatarUrl,
    authorProfileId: profile.id,
    clearAuthorAvatarUrl: profile.avatarUrl == null,
  );
}
