import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_mfa.dart';
import '../models/admin_models.dart';
import '../models/admin_payments.dart';
import '../models/admin_repository.dart';

final adminStatusProvider = FutureProvider.autoDispose<AdminStatus>(
  (ref) => ref.watch(adminRepositoryProvider).getStatus(),
);

final adminMfaStateProvider = FutureProvider.autoDispose<MfaState>((ref) => ref.watch(adminMfaProvider).state());

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>(
  (ref) => ref.watch(adminRepositoryProvider).getDashboard(),
);

final platformSettingsProvider = FutureProvider.autoDispose<PlatformSettings>(
  (ref) => ref.watch(adminRepositoryProvider).getPlatformSettings(),
);

final adminServiceCitiesProvider = FutureProvider.autoDispose<List<AdminServiceCity>>(
  (ref) => ref.watch(adminRepositoryProvider).listServiceCities(),
);

final adminUserProvider = FutureProvider.autoDispose.family<AdminUserDetail, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).getUser(userId),
);

final adminPayoutAccountProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).getPayoutAccount(userId),
);

/// A page-by-page list: what's loaded so far and whether there's more.
class PagedList<T> {
  const PagedList({this.items = const [], this.hasMore = false, this.loadingMore = false, this.loadMoreError});

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;

  PagedList<T> copyWith({List<T>? items, bool? hasMore, bool? loadingMore, Object? loadMoreError}) => PagedList(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// A people search: free text plus an optional role.
class AdminUserQuery {
  const AdminUserQuery({this.text = '', this.role});

  final String text;

  /// `customer`, `provider` or null for both.
  final String? role;

  @override
  bool operator ==(Object other) => other is AdminUserQuery && other.text == text && other.role == role;

  @override
  int get hashCode => Object.hash(text, role);
}

final adminUserSearchProvider =
    AsyncNotifierProvider.autoDispose.family<AdminUserSearch, PagedList<AdminUserSummary>, AdminUserQuery>(
  AdminUserSearch.new,
);

class AdminUserSearch extends AsyncNotifier<PagedList<AdminUserSummary>> {
  AdminUserSearch(this.query);

  final AdminUserQuery query;

  static const pageSize = 30;

  @override
  Future<PagedList<AdminUserSummary>> build() async {
    final page = await ref.read(adminRepositoryProvider).searchUsers(query: query.text, role: query.role, limit: pageSize);
    return PagedList(items: page, hasMore: page.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(adminRepositoryProvider).searchUsers(
            query: query.text,
            role: query.role,
            limit: pageSize,
            offset: current.items.length,
          );
      if (!ref.mounted) return;
      state = AsyncData(PagedList(items: [...current.items, ...page], hasMore: page.length == pageSize));
    } catch (e) {
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}

/// Which audit entries to show: everything, or one record's history.
class AuditFilter {
  const AuditFilter({this.targetType, this.targetId});

  final String? targetType;
  final String? targetId;

  @override
  bool operator ==(Object other) =>
      other is AuditFilter && other.targetType == targetType && other.targetId == targetId;

  @override
  int get hashCode => Object.hash(targetType, targetId);
}

final auditLogProvider = AsyncNotifierProvider.autoDispose.family<AuditLog, PagedList<AuditEntry>, AuditFilter>(
  AuditLog.new,
);

class AuditLog extends AsyncNotifier<PagedList<AuditEntry>> {
  AuditLog(this.filter);

  final AuditFilter filter;

  static const pageSize = 50;

  @override
  Future<PagedList<AuditEntry>> build() async {
    final page = await ref
        .read(adminRepositoryProvider)
        .listAuditLog(limit: pageSize, targetType: filter.targetType, targetId: filter.targetId);
    return PagedList(items: page, hasMore: page.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(adminRepositoryProvider).listAuditLog(
            beforeId: current.items.last.id,
            limit: pageSize,
            targetType: filter.targetType,
            targetId: filter.targetId,
          );
      if (!ref.mounted) return;
      state = AsyncData(PagedList(items: [...current.items, ...page], hasMore: page.length == pageSize));
    } catch (e) {
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}

final adminPaymentsOverviewProvider = FutureProvider.autoDispose<AdminPaymentsOverview>(
  (ref) => ref.watch(adminRepositoryProvider).paymentsOverview(),
);

final adminBookingPaymentProvider = FutureProvider.autoDispose.family<AdminBookingPayment, String>(
  (ref, bookingId) => ref.watch(adminRepositoryProvider).getBookingPayment(bookingId),
);

/// A payments search: a filter (`held`, `failed`, `disputed`, `refunded`)
/// and free text.
class AdminPaymentsQuery {
  const AdminPaymentsQuery({this.filter, this.text = ''});

  final String? filter;
  final String text;

  @override
  bool operator ==(Object other) => other is AdminPaymentsQuery && other.filter == filter && other.text == text;

  @override
  int get hashCode => Object.hash(filter, text);
}

final adminPaymentsProvider =
    AsyncNotifierProvider.autoDispose.family<AdminPaymentsList, PagedList<AdminPaymentSummary>, AdminPaymentsQuery>(
  AdminPaymentsList.new,
);

class AdminPaymentsList extends AsyncNotifier<PagedList<AdminPaymentSummary>> {
  AdminPaymentsList(this.query);

  final AdminPaymentsQuery query;

  static const pageSize = 30;

  @override
  Future<PagedList<AdminPaymentSummary>> build() async {
    final page = await ref
        .read(adminRepositoryProvider)
        .listPayments(filter: query.filter, query: query.text, limit: pageSize);
    return PagedList(items: page, hasMore: page.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(adminRepositoryProvider).listPayments(
            filter: query.filter,
            query: query.text,
            limit: pageSize,
            offset: current.items.length,
          );
      if (!ref.mounted) return;
      state = AsyncData(PagedList(items: [...current.items, ...page], hasMore: page.length == pageSize));
    } catch (e) {
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}
