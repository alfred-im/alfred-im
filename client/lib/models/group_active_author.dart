import 'profile_summary.dart';

/// Autore con almeno un messaggio nello storico del gruppo.
class GroupActiveAuthor {
  const GroupActiveAuthor({
    required this.profile,
    required this.messageCount,
  });

  final ProfileSummary profile;
  final int messageCount;
}
