import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../models/admin_mfa.dart';

/// Six-digit authenticator code entry that verifies against [factorId] as
/// soon as it's complete. Used to finish set-up, to pass two-factor after
/// signing in, to unlock the admin area and to confirm sensitive changes.
class TotpCodeForm extends ConsumerStatefulWidget {
  const TotpCodeForm({super.key, required this.factorId, required this.onVerified, this.autofocus = true});

  final String factorId;
  final VoidCallback onVerified;
  final bool autofocus;

  @override
  ConsumerState<TotpCodeForm> createState() => _TotpCodeFormState();
}

class _TotpCodeFormState extends ConsumerState<TotpCodeForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminMfaProvider).verify(factorId: widget.factorId, code: code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onVerified();
    } catch (e, st) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final offline = isConnectivityError(e);
      if (!offline && e is! AuthException) {
        AppLogger.e('Verifying an authenticator code failed', tag: 'AdminMfa', error: e, stackTrace: st);
      }
      setState(() {
        _error = offline
            ? "You're offline. Check your connection and try again."
            : "That code didn't work. Check your authenticator and try the newest code.";
        _controller.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final theme = PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pinput(
          length: AppConfig.totpCodeLength,
          controller: _controller,
          enabled: !_busy,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          defaultPinTheme: theme,
          focusedPinTheme: theme.copyWith(
            decoration: theme.decoration!.copyWith(border: Border.all(color: scheme.primary, width: 2)),
          ),
          errorPinTheme: theme.copyWith(
            decoration: theme.decoration!.copyWith(border: Border.all(color: scheme.secondary, width: 2)),
          ),
          forceErrorState: _error != null,
          onCompleted: _verify,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: _busy
              ? const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
              : _error != null
                  ? Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.secondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                    )
                  : Text(
                      'Open your authenticator app and enter the 6-digit code for Myglo Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 13.5),
                    ),
        ),
      ],
    );
  }
}
