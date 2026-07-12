import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/authentication/models/auth_repository.dart';

class HomeProvider {
  final String id;
  final String providerName;
  final String addressText;
  final String? profilePic;

  HomeProvider({
    required this.id,
    required this.providerName,
    required this.addressText,
    this.profilePic,
  });

  factory HomeProvider.fromJson(Map<String, dynamic> json) {
    return HomeProvider(
      id: json['id'] as String,
      providerName: json['provider_name'] as String? ?? 'Unknown Provider',
      addressText: json['address_text'] as String? ?? 'No location provided',
      profilePic: json['profiles']?['profile_pic'] as String?,
    );
  }
}

final allProvidersProvider = FutureProvider.autoDispose<List<HomeProvider>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final response = await client.from('provider_details').select('*, profiles(profile_pic)');
  return (response as List).map((e) => HomeProvider.fromJson(e)).toList();
});
