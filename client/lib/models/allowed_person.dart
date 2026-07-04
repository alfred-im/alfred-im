import '../models/profile_summary.dart';

/// Voce nella lista persone consentite in ricezione.
class AllowedPerson {
  const AllowedPerson({
    required this.entryId,
    required this.profile,
  });

  final String entryId;
  final ProfileSummary profile;

  String get displayName => profile.displayName;
}
