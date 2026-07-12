import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/provider_item.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsyncValue = ref.watch(allProvidersProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(text: 'Welcome '),
                    TextSpan(
                      text: 'back',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: Image.asset(
                  'assets/graphics/Underline.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
              HomeSearchBar(),
              SizedBox(height: 32),
              Text(
                'Available Providers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              providersAsyncValue.when(
                data: (providers) {
                  if (providers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No service provider found near you',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: providers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      final name = provider.providerName;
                      
                      return ProviderItemWithImage(
                        category: 'BEAUTY', // Static category for now
                        name: name,
                        location: provider.addressText,
                        status: 'Available',
                        statusColor: Colors.green,
                        imageUrl: provider.profilePic,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error loading providers: $error'),
                ),
              ),
              // Padding at the bottom for the navigation bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
