import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/business_model.dart';
import '../domain/customer_model.dart';
import 'auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  /// Saves a customer to the 'customers' table in Supabase
  Future<void> saveCustomer(CustomerModel customer) async {
    await _client.from('customers').upsert(customer.toJson());
  }

  /// Saves a business to the 'businesses' table in Supabase
  Future<void> saveBusiness(BusinessModel business) async {
    await _client.from('businesses').upsert(business.toJson());
  }

  /// Fetches a Customer profile from the DB
  Future<CustomerModel?> getCustomer(String id) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return CustomerModel.fromJson(response);
  }

  /// Fetches a Business profile from the DB
  Future<BusinessModel?> getBusiness(String id) async {
    final response = await _client
        .from('businesses')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return BusinessModel.fromJson(response);
  }
}
