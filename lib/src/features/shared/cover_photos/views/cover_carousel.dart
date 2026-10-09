import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/skeleton/skeletons.dart';

/// Brand artwork shown when a provider hasn't added cover photos.
const String defaultCoverAsset = 'assets/images/myglo_cover.png';

/// A provider's cover photos as a swipeable banner with page dots. Tapping
/// opens them full screen. With no photos it shows the Myglo artwork.
class CoverCarousel extends StatefulWidget {
  const CoverCarousel({
    super.key,
    required this.photos,
    this.heroPrefix = 'cover',
    this.indicatorPadding = const EdgeInsets.only(bottom: 12),
    this.indicatorAlignment = MainAxisAlignment.center,
    this.scrim = true,
  });

  final List<String> photos;

  /// Keeps hero tags unique when two carousels could be on screen.
  final String heroPrefix;

  /// Where the page dots sit, e.g. lifted above a sheet that overlaps the
  /// bottom of the banner.
  final EdgeInsets indicatorPadding;

  /// Horizontal placement of the dots (e.g. to the side of an avatar).
  final MainAxisAlignment indicatorAlignment;

  /// Top and bottom shading so light photos don't wash out the controls
  /// drawn over them.
  final bool scrim;

  @override
  State<CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<CoverCarousel> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(CoverCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.photos.length && widget.photos.isNotEmpty) {
      _page = widget.photos.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_page);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _heroTag(int index) => '${widget.heroPrefix}-$index-${widget.photos[index]}';

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          Image.asset(defaultCoverAsset, fit: BoxFit.cover)
        else
          PageView.builder(
            controller: _pages,
            itemCount: photos.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => Semantics(
              image: true,
              button: true,
              label: 'Cover photo ${index + 1} of ${photos.length}. Double tap to view full screen.',
              child: GestureDetector(
                onTap: () => CoverPhotoViewer.open(
                  context,
                  photos: photos,
                  initialIndex: index,
                  heroTagFor: _heroTag,
                  onPageChanged: (page) {
                    if (_pages.hasClients) _pages.jumpToPage(page);
                  },
                ),
                child: Hero(
                  tag: _heroTag(index),
                  child: CachedNetworkImage(
                    imageUrl: photos[index],
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                    errorWidget: (_, _, _) => Image.asset(defaultCoverAsset, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
        if (widget.scrim)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        if (photos.length > 1)
          Positioned(
            left: widget.indicatorPadding.left,
            right: widget.indicatorPadding.right,
            bottom: widget.indicatorPadding.bottom,
            child: IgnorePointer(
              child: PageDots(count: photos.length, index: _page, alignment: widget.indicatorAlignment),
            ),
          ),
      ],
    );
  }
}

/// Small page indicator: the current page is a wider pill.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    this.color = Colors.white,
    this.alignment = MainAxisAlignment.center,
  });

  final int count;
  final int index;
  final Color color;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: i == index ? 1 : 0.55),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
            ),
          ),
      ],
    );
  }
}

/// Full-screen, zoomable view of cover photos.
class CoverPhotoViewer extends StatefulWidget {
  const CoverPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.heroTagFor,
    this.onPageChanged,
  });

  final List<String> photos;
  final int initialIndex;
  final String Function(int index) heroTagFor;
  final ValueChanged<int>? onPageChanged;

  static Future<void> open(
    BuildContext context, {
    required List<String> photos,
    required int initialIndex,
    required String Function(int index) heroTagFor,
    ValueChanged<int>? onPageChanged,
  }) {
    HapticFeedback.selectionClick();
    return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => CoverPhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        heroTagFor: heroTagFor,
        onPageChanged: onPageChanged,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<CoverPhotoViewer> createState() => _CoverPhotoViewerState();
}

class _CoverPhotoViewerState extends State<CoverPhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (page) {
                setState(() => _page = page);
                widget.onPageChanged?.call(page);
              },
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: widget.heroTagFor(index),
                    child: CachedNetworkImage(
                      imageUrl: widget.photos[index],
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    if (widget.photos.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_page + 1} of ${widget.photos.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
