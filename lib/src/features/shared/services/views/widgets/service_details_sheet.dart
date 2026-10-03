import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../providers/provider_profiles/models/service_catalog.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import 'service_tile.dart';

/// Shown until providers can set their own cancellation policy.
const String defaultCancellationNote =
    'Cancellation terms are set by each provider. Confirm them when you arrange your appointment.';

/// Opens the lightweight details sheet for [service] on top of the current
/// screen. It opens at 60% height and can be dragged up to 90%.
///
/// Pass [onBook] to show the sticky booking bar. Leave it null for viewers who
/// can't book (the owning provider previewing their own service, or another
/// provider). [bookingNote] is shown above the policy when booking happens
/// outside the app.
Future<void> showServiceDetailsSheet(
  BuildContext context, {
  required ServiceModel service,
  VoidCallback? onBook,
  String bookLabel = 'Book now',
  String? bookingNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ServiceDetailsSheet(
      service: service,
      bookLabel: bookLabel,
      bookingNote: bookingNote,
      onBook: onBook == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onBook();
            },
    ),
  );
}

class _ServiceDetailsSheet extends StatelessWidget {
  const _ServiceDetailsSheet({
    required this.service,
    required this.bookLabel,
    required this.bookingNote,
    required this.onBook,
  });

  static const double _initialSize = 0.6;
  static const double _maxSize = 0.9;

  final ServiceModel service;
  final String bookLabel;
  final String? bookingNote;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final details = ServiceDescription.parse(service.description);
    final category = service.category?.trim() ?? '';
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _initialSize,
      minChildSize: 0.35,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_initialSize],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // Part of the scrollable, so dragging the handle moves the sheet.
                    const SliverPersistentHeader(pinned: true, delegate: _HandleHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      sliver: SliverList.list(
                        children: [
                          _Header(service: service, category: category),
                          const SizedBox(height: 20),
                          _PriceCallout(price: service.price),
                          if (details.included.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _SectionTitle("What's included"),
                            const SizedBox(height: 10),
                            for (final item in details.included) _IncludedItem(item),
                          ],
                          if (details.summary.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _SectionTitle('About this service'),
                            const SizedBox(height: 8),
                            Text(details.summary, style: TextStyle(fontSize: 14.5, height: 1.5, color: muted)),
                          ],
                          if (bookingNote != null) ...[
                            const SizedBox(height: 24),
                            _NoteRow(icon: Icons.info_outline_rounded, title: 'How booking works', body: bookingNote!),
                          ],
                          const SizedBox(height: 16),
                          const _NoteRow(
                            icon: Icons.event_busy_outlined,
                            title: 'Cancellation policy',
                            body: defaultCancellationNote,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onBook != null) _BookingBar(price: service.price, label: bookLabel, onBook: onBook!),
            ],
          ),
        );
      },
    );
  }
}

class _HandleHeader extends SliverPersistentHeaderDelegate {
  const _HandleHeader();

  static const double _height = 24;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scheme = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HandleHeader oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({required this.service, required this.category});

  final ServiceModel service;
  final String category;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ServiceThumbnail(imageUrl: service.imageUrl, size: 84, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (category.isNotEmpty)
                    _Tag(label: category.toUpperCase(), color: scheme.secondary),
                  _Tag(
                    label: Formatters.duration(service.durationMinutes),
                    icon: Icons.schedule_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: color),
          ),
        ],
      ),
    );
  }
}

class _PriceCallout extends StatelessWidget {
  const _PriceCallout({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.aud(price),
            style: TextStyle(fontSize: 30, height: 1, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AUD · incl. GST where applicable',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
      ),
    );
  }
}

class _IncludedItem extends StatelessWidget {
  const _IncludedItem(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: context.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.price, required this.label, required this.onBook});

  final double price;
  final String label;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55))),
              Text(
                Formatters.aud(price),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: Text(label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
