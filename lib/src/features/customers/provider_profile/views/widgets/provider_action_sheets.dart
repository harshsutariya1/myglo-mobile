import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import '../../../../shared/services/views/widgets/service_details_sheet.dart';
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

/// Opens the booking flow for [service]'s provider with [service] already
/// selected.
void openServiceBooking(BuildContext context, ServiceModel service) {
  context.pushNamed(
    AppRoute.selectServices.name,
    pathParameters: {'id': service.providerId},
    queryParameters: {selectServicesInitialServiceParam: service.id},
  );
}

/// Opens the details sheet for a service the client may want to book. Its
/// call to action starts the booking flow with this service selected.
Future<void> showServiceBookingSheet(
  BuildContext context, {
  required ServiceModel service,
  String? excludePostId,
}) {
  return showServiceDetailsSheet(
    context,
    service: service,
    excludePostId: excludePostId,
    onBook: () {
      if (context.mounted) openServiceBooking(context, service);
    },
  );
}
