import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/discovery_feed_controller.dart';
import 'widgets/discovery_grid_view.dart';
import 'widgets/discovery_feed_view.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsyncValue = ref.watch(discoveryFeedProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                // Sparkle could go here if we had an asset, we'll omit for simplicity
              ],
            ),
            // Pink underline graphic
            Image.asset(
              'assets/graphics/Underline.png',
              height: 12, // adjust as needed
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if asset is missing
                return Container(
                  height: 4,
                  width: 80,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: context.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black, size: 28),
            onPressed: () {
              // Search action
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Toggle bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: context.colorScheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: context.colorScheme.tertiary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(text: 'For you'),
                  Tab(text: 'Following'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Tab views
          Expanded(
            child: postsAsyncValue.when(
              data: (posts) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    DiscoveryGridView(posts: posts),
                    DiscoveryFeedView(posts: posts),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading posts: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
