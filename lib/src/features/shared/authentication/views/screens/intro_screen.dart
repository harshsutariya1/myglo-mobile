import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_theme.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<String> _images = [
    AppAssets.intro1,
    AppAssets.intro2,
    AppAssets.intro3,
  ];

  final List<String> _titles = [
    'Discover Services',
    'Book Experts',
    'Experience Beauty',
  ];

  final List<String> _subtitles = [
    'Find inspiration and discover premium beauty services near you.',
    'Book appointments with top-rated professionals instantly.',
    'Enjoy a luxurious experience and feel your absolute best.',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSkip() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    if (index == 3) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          AppAssets.onboardingBg,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: context.colorScheme.tertiary.withValues(alpha: 0.5),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 100,
                                color: context.colorScheme.surface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              _images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: context.colorScheme.tertiary.withValues(alpha: 0.5),
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 100,
                                    color: context.colorScheme.surface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _titles[index],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _subtitles[index],
                          style: TextStyle(
                            fontSize: 16,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
              // Dot indicators
              if (_currentIndex < 3) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? context.colorScheme.primary
                            : context.colorScheme.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 32),
              ],
              // Buttons
              _currentIndex == 3
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.push('/auth');
                            },
                            child: const Text('Get started'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            context.go('/main');
                          },
                          child: Text(
                            'Continue as guest',
                            style: TextStyle(
                              color: context.colorScheme.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _onSkip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: context.colorScheme.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _onNext,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
