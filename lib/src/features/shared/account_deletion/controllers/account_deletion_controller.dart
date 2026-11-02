import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_deletion_repository.dart';
import '../models/account_deletion_status.dart';

/// The signed-in user's deletion status, loaded when the screen opens.
final accountDeletionStatusProvider = FutureProvider.autoDispose<AccountDeletionStatus>(
  (ref) => ref.watch(accountDeletionRepositoryProvider).getStatus(),
);
