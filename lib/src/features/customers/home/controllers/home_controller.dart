import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
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
      profilePic: json['profile_pic'] as String?,
    );
  }
}

final allProvidersProvider = FutureProvider.autoDispose<List<HomeProvider>>((ref) async {
  AppLogger.d('allProvidersProvider: Fetching providers for Home screen...', tag: 'HomeController');
  final sw = Stopwatch()..start();
  try {
    final client = ref.read(supabaseClientProvider);
    final response = await client.from('profiles').select().eq('role', 'provider');
    sw.stop();
    final providers = (response as List).map((e) => HomeProvider.fromJson(e)).toList();
    AppLogger.api('profiles.select(role=provider)', count: providers.length, duration: sw.elapsed);
    return providers;
  } catch (e, st) {
    AppLogger.e('allProvidersProvider: Failed to load providers for Home', tag: 'HomeController', error: e, stackTrace: st);
    rethrow;
  }
});
