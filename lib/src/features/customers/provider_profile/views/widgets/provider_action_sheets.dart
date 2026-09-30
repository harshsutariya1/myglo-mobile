import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import 'provider_profile_header.dart';

/// Shows the contact details a provider has chosen to make public.
///
/// `public_profiles` masks email and phone unless the provider opted in, so a
/// null value here means "not shared", not "missing".
Future<void> showProviderContactSheet(BuildContext context, ProfileModel profile) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final email = profile.email?.trim() ?? '';
      final phone = profile.phoneNumber?.trim() ?? '';
      final hasContact = email.isNotEmpty || phone.isNotEmpty;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contact ${providerDisplayName(profile)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: sheetContext.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (!hasContact)
                Text(
                  "This provider hasn't shared contact details yet.",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: sheetContext.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              if (phone.isNotEmpty)
                _CopyableContact(icon: Icons.phone_outlined, label: 'Phone', value: phone),
              if (email.isNotEmpty)
                _CopyableContact(icon: Icons.mail_outline, label: 'Email', value: email),
            ],
          ),
        ),
      );
    },
  );
}

class _CopyableContact extends StatelessWidget {
  const _CopyableContact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.colorScheme.secondary),
      title: Text(label),
      subtitle: SelectableText(value),
      trailing: IconButton(
        tooltip: 'Copy $label',
        icon: const Icon(Icons.copy_rounded, size: 20),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          context.showAppSnackBar('$label copied');
        },
      ),
    );
  }
}

/// Summarises a service the client wants to book.
///
/// In-app booking isn't available yet (there is no bookings table), so the
/// sheet points the client to the provider's contact details instead of
/// pretending to reserve a slot.
Future<void> showServiceBookingSheet(
  BuildContext context, {
  required ServiceModel service,
  required ProfileModel? provider,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final scheme = sheetContext.colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                service.name,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatters.aud(service.price)}  •  ${Formatters.duration(service.durationMinutes)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: scheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Online booking isn't available yet. Contact the provider "
                        'to arrange a time for this service.',
                        style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  // The profile may still be loading (or have failed) when a
                  // service row is tapped; contact needs it.
                  onPressed: provider == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          showProviderContactSheet(context, provider);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Contact provider'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
