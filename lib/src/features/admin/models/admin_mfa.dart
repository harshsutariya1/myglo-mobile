import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/models/auth_repository.dart';

final adminMfaProvider = Provider<AdminMfa>((ref) => SupabaseAdminMfa(ref.watch(supabaseClientProvider)));

/// A TOTP factor being set up: what the admin adds to their authenticator.
class TotpEnrollment {
  const TotpEnrollment({required this.factorId, required this.secret, required this.uri});

  final String factorId;

  /// Base32 secret to type into an authenticator by hand.
  final String secret;

  /// `otpauth://` link that opens an authenticator app with the secret.
  final String uri;
}

/// The admin's two-factor state on this device, read from the session.
class MfaState {
  const MfaState({required this.verifiedFactorId, required this.isAal2, this.lastVerifiedAt});

  /// The verified TOTP factor, or null if the admin hasn't set one up.
  final String? verifiedFactorId;

  /// The session has passed two-factor.
  final bool isAal2;

  /// When the session last passed TOTP.
  final DateTime? lastVerifiedAt;

  bool get isEnrolled => verifiedFactorId != null;
}

/// Two-factor (TOTP) for admin accounts. The server enforces it; this only
/// lets the admin set it up and pass it.
abstract interface class AdminMfa {
  /// Current state; refreshes the session to see newly verified factors.
  Future<MfaState> state();

  /// Starts setting up an authenticator, discarding any half-finished one.
  Future<TotpEnrollment> enroll();

  /// Checks [code] against [factorId]; on success the session becomes aal2
  /// with a fresh TOTP time.
  Future<void> verify({required String factorId, required String code});
}

class SupabaseAdminMfa implements AdminMfa {
  SupabaseAdminMfa(this._client);

  final SupabaseClient _client;

  static const _tag = 'AdminMfa';
  static const _issuer = 'Myglo Admin';

  GoTrueMFAApi get _mfa => _client.auth.mfa;

  @override
  Future<MfaState> state() async {
    final factors = await _mfa.listFactors();
    final level = _mfa.getAuthenticatorAssuranceLevel();
    final totpTimes = level.currentAuthenticationMethods
        .where((m) => m.method == AMRMethod.totp)
        .map((m) => m.timestamp)
        .toList()
      ..sort();
    return MfaState(
      verifiedFactorId: factors.totp.isEmpty ? null : factors.totp.first.id,
      isAal2: level.currentLevel == AuthenticatorAssuranceLevels.aal2,
      lastVerifiedAt: totpTimes.isEmpty ? null : totpTimes.last,
    );
  }

  @override
  Future<TotpEnrollment> enroll() async {
    // An abandoned setup leaves an unverified factor that blocks a new one
    // with the same name; clear those first.
    final existing = await _mfa.listFactors();
    for (final factor in existing.all) {
      if (factor.factorType == FactorType.totp && factor.status != FactorStatus.verified) {
        await _mfa.unenroll(factor.id);
      }
    }
    final response = await _mfa.enroll(factorType: FactorType.totp, issuer: _issuer, friendlyName: 'Authenticator');
    final totp = response.totp;
    if (totp == null) throw StateError('TOTP enrolment returned no secret');
    AppLogger.i('Started TOTP enrolment', tag: _tag);
    return TotpEnrollment(factorId: response.id, secret: totp.secret, uri: totp.uri);
  }

  @override
  Future<void> verify({required String factorId, required String code}) async {
    await _mfa.challengeAndVerify(factorId: factorId, code: code);
    AppLogger.i('TOTP verified', tag: _tag);
  }
}
