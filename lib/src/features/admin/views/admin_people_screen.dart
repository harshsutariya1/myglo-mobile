import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive/adaptive_list_detail.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import 'admin_user_detail_screen.dart';
import 'widgets/admin_widgets.dart';

/// Search clients and providers. On wide screens the selected person's
/// details show beside the list; on phones they open as their own page.
class AdminPeopleScreen extends ConsumerStatefulWidget {
  const AdminPeopleScreen({super.key, this.initialRole});

  /// `customer`, `provider` or null for everyone.
  final String? initialRole;

  @override
  ConsumerState<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends ConsumerState<AdminPeopleScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  late AdminUserQuery _query = AdminUserQuery(role: widget.initialRole);
  String? _selectedId;

  @override
  void didUpdateWidget(AdminPeopleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRole != widget.initialRole) {
      _query = AdminUserQuery(text: _query.text, role: widget.initialRole);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(AppConfig.adminSearchDebounce, () {
      if (mounted && text.trim() != _query.text) {
        setState(() => _query = AdminUserQuery(text: text.trim(), role: _query.role));
      }
    });
  }

  void _setRole(String? role) => setState(() => _query = AdminUserQuery(text: _query.text, role: role));

  void _open(AdminUserSummary user) {
    if (isWideLayout(context)) {
      setState(() => _selectedId = user.userId);
    } else {
      context.goNamed(AppRoute.adminUser.name, pathParameters: {'userId': user.userId});
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(adminUserSearchProvider(_query));
    final scheme = context.colorScheme;

    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Name, business, email, phone or id',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              fillColor: scheme.onSurface.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (role, label) in const [(null, 'Everyone'), ('provider', 'Providers'), ('customer', 'Clients')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _query.role == role,
                    onSelected: (_) => _setRole(role),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (results) {
            AsyncData(:final value) when value.items.isEmpty => Center(
                child: Text(
                  _query.text.isEmpty ? 'No accounts yet.' : 'Nobody matches "${_query.text}".',
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUserSearchProvider(_query)),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                      ref.read(adminUserSearchProvider(_query).notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: value.items.length + (value.hasMore || value.loadMoreError != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == value.items.length) {
                        return value.loadMoreError != null
                            ? TextButton(
                                onPressed: () => ref.read(adminUserSearchProvider(_query).notifier).loadMore(),
                                child: const Text("Couldn't load more. Try again"),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                      }
                      final user = value.items[index];
                      return AdminUserTile(
                        user: user,
                        selected: user.userId == _selectedId,
                        onTap: () => _open(user),
                      );
                    },
                  ),
                ),
              ),
            AsyncError(:final error) =>
              AdminErrorView(error: error, onRetry: () => ref.invalidate(adminUserSearchProvider(_query))),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: AdaptiveListDetail(
        list: list,
        detail: _selectedId == null ? null : AdminUserDetailView(key: ValueKey(_selectedId), userId: _selectedId!),
        placeholder: Center(
          child: Text('Select someone to see their details.', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5))),
        ),
      ),
    );
  }
}

class AdminUserTile extends StatelessWidget {
  const AdminUserTile({super.key, required this.user, required this.onTap, this.selected = false});

  final AdminUserSummary user;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final subtitle = [
      if (user.isProvider && user.displayName != null) user.displayName!,
      ?user.email,
    ].join(' · ');
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundImage: user.avatarUrl == null ? null : CachedNetworkImageProvider(user.avatarUrl!),
        child: Icon(user.isProvider ? Icons.storefront_outlined : Icons.person_outline, color: scheme.onPrimaryContainer),
      ),
      title: Text(user.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: AdminChip(
        label: user.isProvider ? 'Provider' : 'Client',
        color: user.isProvider ? scheme.secondary : AppTheme.success,
      ),
    );
  }
}
