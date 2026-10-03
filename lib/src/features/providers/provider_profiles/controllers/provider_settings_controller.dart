import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../../../shared/authentication/models/user_role.dart';

/// Which contact detail a visibility toggle controls.
enum ContactField { email, phone }

/// Quick settings a provider can change in place, without opening a form.
final providerSettingsActionsProvider = Provider<ProviderSettingsActions>(ProviderSettingsActions.new);

class ProviderSettingsActions {
  ProviderSettingsActions(this._ref);

  final Ref _ref;

  /// Shows or hides [field] on the provider's public profile. Returns whether
  /// the change was saved. `public_profiles` masks hidden values server-side.
  Future<bool> setContactVisibility(ContactField field, {required bool visible}) async {
    final user = _ref.read(userProfileProvider).value;
    if (user == null || !user.isProvider) return false;
    try {
      await _ref.read(userRepositoryProvider).updateUserProfile(
            id: user.profile.id,
            role: UserRole.provider,
            isEmailPublic: field == ContactField.email ? visible : null,
            isPhonePublic: field == ContactField.phone ? visible : null,
          );
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (e, st) {
      // The repository has already reported the failure.
      AppLogger.w('Failed to update ${field.name} visibility', tag: 'ProviderSettings', error: e, stackTrace: st);
      return false;
    }
  }
}
