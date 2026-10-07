import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';

/// Moves back through the booking flow to [step] (e.g. from payment to the
/// time step when the chosen time was just taken), keeping everything chosen
/// along the way.
void popBookingFlowTo(BuildContext context, AppRoute step) {
  Navigator.of(context).popUntil((route) => route.settings.name == step.name || route.isFirst);
}

/// Opens the next step of the booking flow for [providerId].
void pushBookingStep(BuildContext context, AppRoute step, String providerId) {
  context.pushNamed(step.name, pathParameters: {'id': providerId});
}
