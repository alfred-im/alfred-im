import '../models/contact.dart';
import 'supabase_bootstrap.dart';

class ContactService {
  Future<List<Contact>> fetchContacts(String ownerId) async {
    final rows = await supabase
        .from('contacts')
        .select()
        .eq('owner_id', ownerId)
        .order('display_name');

    return rows.map((r) => Contact.fromJson(r)).toList();
  }

  Future<List<ProfileSearchResult>> searchProfiles(String query) async {
    if (query.trim().length < 2) return [];

    final rows = await supabase.rpc(
      'search_profiles',
      params: {'p_query': query.trim(), 'p_limit': 20},
    );

    return (rows as List<dynamic>)
        .map((r) => ProfileSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Contact> addInternalContact({
    required String ownerId,
    required ProfileSearchResult profile,
  }) async {
    final row = await supabase
        .from('contacts')
        .insert({
          'owner_id': ownerId,
          'protocol': 'internal',
          'linked_profile_id': profile.id,
          'display_name': profile.displayName,
          if (profile.avatarUrl != null) 'avatar_url': profile.avatarUrl,
        })
        .select()
        .single();

    return Contact.fromJson(row);
  }

  Future<Contact> addExternalContact({
    required String ownerId,
    required ContactProtocol protocol,
    required String externalAddress,
    required String displayName,
  }) async {
    final row = await supabase
        .from('contacts')
        .insert({
          'owner_id': ownerId,
          'protocol': protocol.name,
          'external_address': externalAddress,
          'display_name': displayName,
        })
        .select()
        .single();

    return Contact.fromJson(row);
  }

  Future<void> deleteContact(String contactId) async {
    await supabase.from('contacts').delete().eq('id', contactId);
  }
}
