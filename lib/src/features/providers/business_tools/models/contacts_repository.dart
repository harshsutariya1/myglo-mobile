import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import 'provider_contact.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in provider's clients. Each contact's totals are aggregated in
/// the database (see the provider_contacts migration), so no booking rows
/// are downloaded to build the list.
class ContactsRepository {
  ContactsRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'ContactsRepository';

  /// A page of contacts, most recent appointment first. Pass the last
  /// contact already shown as [after] for the next page; [search] matches
  /// names and phone numbers. Throws a [BookingFailure] when the caller isn't
  /// a signed-in provider; other failures are reported and rethrown.
  Future<List<ProviderContact>> list({String? search, ProviderContact? after, required int limit}) async {
    final query = search?.trim() ?? '';
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('get_provider_contacts', params: {
        'p_search': query.isEmpty ? null : query,
        'p_after_last_at': after?.lastStartsAt.toUtc().toIso8601String(),
        'p_after_client_id': after?.clientId,
        'p_limit': limit,
      }) as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.get_provider_contacts', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) ProviderContact.fromJson(Map<String, dynamic>.from(row as Map))];
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Loading contacts');
    }
  }

  /// One contact, or null when [clientId] has never booked with the caller.
  Future<ProviderContact?> get(String clientId) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('get_provider_contacts', params: {
        'p_client_id': clientId,
        'p_limit': 1,
      }) as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.get_provider_contacts', endpoint: 'client=$clientId', duration: sw.elapsed);
      return rows.isEmpty ? null : ProviderContact.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Loading contact $clientId');
    }
  }

  /// How many clients have booked with the caller.
  Future<int> count() async {
    final sw = Stopwatch()..start();
    try {
      final count = await _client.rpc('count_provider_contacts');
      sw.stop();
      AppLogger.api('rpc.count_provider_contacts', duration: sw.elapsed);
      return (count as num? ?? 0).toInt();
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Counting contacts');
    }
  }
}
