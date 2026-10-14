import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../../shared/bookings/views/widgets/booking_card.dart' show PersonAvatar;
import '../controllers/contacts_controllers.dart';
import '../models/provider_contact.dart';
import 'widgets/client_contact_sheet.dart';

/// Everyone who has booked with the signed-in provider, most recent
/// appointment first, searchable by name or phone. Tapping a client opens
/// their bookings in a sheet.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// The search the list shows, trimmed (empty for everyone).
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() {}); // Shows or hides the clear button straight away.
    _debounce?.cancel();
    _debounce = Timer(AppConfig.contactsSearchDebounce, () {
      final query = text.trim();
      if (mounted && query != _query) setState(() => _query = query);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _refresh() async {
    ref.invalidate(contactsProvider(_query));
    ref.invalidate(providerContactCountProvider);
    try {
      await ref.read(contactsProvider(_query).future);
    } catch (_) {
      // Shown inline by the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final async = ref.watch(contactsProvider(_query));
    final page = async.value;
    final total = ref.watch(providerContactCountProvider).value;
    // Nobody to search through yet: the empty state says it all.
    final showSearch = _search.text.isNotEmpty || (total ?? page?.items.length ?? 0) > 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Contacts'),
      ),
      body: GestureDetector(
        // Tapping outside the search box closes the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: _refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) {
                ref.read(contactsProvider(_query).notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (showSearch)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SearchField(controller: _search, onChanged: _onSearchChanged, onClear: _clearSearch),
                    ),
                  ),
                if (showSearch && _query.isEmpty && total != null && total > 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${Formatters.compactCount(total)} ${total == 1 ? 'client' : 'clients'} · Most recent first',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                if (page == null)
                  SliverToBoxAdapter(
                    child: switch (async) {
                      AsyncError(:final error) => SectionErrorView(
                          title: "Contacts didn't load",
                          message: describeLoadError(error, subject: 'your contacts'),
                          onRetry: () => ref.invalidate(contactsProvider(_query)),
                        ),
                      _ => const ContactListSkeleton(),
                    },
                  )
                else if (page.items.isEmpty)
                  SliverToBoxAdapter(
                    child: _query.isEmpty
                        ? const SectionEmptyView(
                            icon: Icons.people_alt_outlined,
                            title: 'No clients yet',
                            message: 'Everyone who books with you appears here, with all their appointments.',
                          )
                        : SectionEmptyView(
                            icon: Icons.person_search_outlined,
                            title: 'No matches',
                            message: 'No client matches "$_query". Try a name or phone number.',
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 6),
                    sliver: SliverList.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 86,
                        endIndent: 20,
                        color: scheme.onSurface.withValues(alpha: 0.07),
                      ),
                      itemBuilder: (context, index) {
                        final contact = page.items[index];
                        return ContactTile(
                          contact: contact,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            showClientContactSheet(context, contact: contact);
                          },
                        );
                      },
                    ),
                  ),
                if (page != null && (page.loadingMore || page.loadMoreFailed))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: page.loadingMore
                            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(
                                onPressed: () => ref.read(contactsProvider(_query).notifier).loadMore(retry: true),
                                child: const Text("Couldn't load more. Try again"),
                              ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      maxLength: 100,
      style: TextStyle(fontSize: 15, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Search by name or phone',
        hintStyle: TextStyle(fontSize: 15, color: muted),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(Icons.search_rounded, size: 22, color: muted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, size: 20, color: muted),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.6), width: 1.4),
        ),
      ),
    );
  }
}

/// What a contact has coming up, or when they were last in.
({IconData icon, String text, bool upcoming}) contactActivity(ProviderContact contact) {
  final currentYear = BookingTime.todayIn(contact.timeZone).year;
  if (contact.nextStartsAtLocal case final next?) {
    return (icon: Icons.event_available_rounded, text: 'Next · ${contactDate(next, currentYear, withTime: true)}', upcoming: true);
  }
  if (contact.lastVisitLocal case final last?) {
    return (icon: Icons.history_rounded, text: 'Last visit ${contactDate(last, currentYear)}', upcoming: false);
  }
  return (icon: Icons.event_busy_outlined, text: 'No visits yet', upcoming: false);
}

/// `Tue 7 Oct` (with `, 9:30 am` when [withTime]), or `7 Oct 2025` outside
/// [currentYear]. Reads a provider-local wall clock.
String contactDate(DateTime wallClock, int currentYear, {bool withTime = false}) {
  final date = wallClock.year == currentYear
      ? Formatters.dateShort(wallClock)
      : '${wallClock.day} ${Formatters.monthShort(wallClock)} ${wallClock.year}';
  return withTime ? '$date, ${Formatters.time(wallClock)}' : date;
}

/// `No visits`, `1 visit`, `12 visits`.
String visitCount(int count) => switch (count) {
      0 => 'No visits',
      1 => '1 visit',
      _ => '${Formatters.compactCount(count)} visits',
    };

/// A client in the contacts list: photo, name, what's next (or when they
/// were last in), what they've paid and how often they've visited.
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.onTap});

  final ProviderContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final activity = contactActivity(contact);
    final activityColor = activity.upcoming ? Color.lerp(AppTheme.success, Colors.black, 0.2)! : muted;
    final paid = contact.totalPaidCents > 0 ? Formatters.audCents(contact.totalPaidCents) : null;

    return Semantics(
      button: true,
      label: '${contact.displayName}, ${activity.text}, ${visitCount(contact.completedCount)}'
          '${paid == null ? '' : ', $paid paid'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
          child: Row(
            children: [
              PersonAvatar(name: contact.displayName, url: contact.avatarUrl, size: 50),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(activity.icon, size: 14, color: activityColor),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            activity.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: activity.upcoming ? FontWeight.w700 : FontWeight.w500,
                              color: activityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (paid != null)
                    Text(
                      paid,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                  if (contact.completedCount > 0) ...[
                    if (paid != null) const SizedBox(height: 3),
                    Text(
                      visitCount(contact.completedCount),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows with the footprint of [ContactTile]s.
class ContactListSkeleton extends StatelessWidget {
  const ContactListSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    SkeletonBox.circle(size: 50),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonText(style: TextStyle(fontSize: 16), widthFactor: 0.55),
                          SizedBox(height: 6),
                          SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.75),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonBox(width: 48, height: 16, borderRadius: 6),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
