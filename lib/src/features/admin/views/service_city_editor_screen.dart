import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/maps/app_map.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import '../models/admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// Adds a city ([city] null) or edits one: name, state, centre (move the map
/// under the pin) and radius.
class ServiceCityEditorScreen extends ConsumerStatefulWidget {
  const ServiceCityEditorScreen({super.key, this.city});

  final AdminServiceCity? city;

  @override
  ConsumerState<ServiceCityEditorScreen> createState() => _ServiceCityEditorScreenState();
}

class _ServiceCityEditorScreenState extends ConsumerState<ServiceCityEditorScreen> {
  static const _states = ['QLD', 'NSW', 'VIC', 'ACT', 'TAS', 'SA', 'WA', 'NT'];
  static const _minRadiusKm = 1.0;
  static const _maxRadiusKm = 100.0;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.city?.name ?? '');
  late String _state = widget.city?.state ?? 'QLD';
  late double _radiusKm = (widget.city?.radiusM ?? 25000) / 1000;
  late GeoPoint _centre = widget.city == null
      ? AppConfig.mapDefaultCenter
      : GeoPoint(latitude: widget.city!.latitude, longitude: widget.city!.longitude);
  bool _saving = false;

  bool get _isNew => widget.city == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_centre.isInAustralia) {
      context.showAppSnackBar('Move the map so the pin is inside Australia.', isError: true);
      return;
    }
    String? reason;
    if (!_isNew) {
      reason = await askAdminReason(context, title: 'Save ${widget.city!.name}');
      if (reason == null || !mounted) return;
    }
    setState(() => _saving = true);
    final id = await runAdminAction(
      context,
      ref,
      successMessage: _isNew ? 'City added' : 'City saved',
      action: () => ref.read(adminRepositoryProvider).saveServiceCity(
            cityId: widget.city?.cityId,
            name: _name.text.trim(),
            state: _state,
            latitude: _centre.latitude,
            longitude: _centre.longitude,
            radiusM: (_radiusKm * 1000).round(),
            isActive: widget.city?.isActive ?? true,
            reason: reason,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      ref.invalidate(adminServiceCitiesProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Add city' : 'Edit ${widget.city!.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'City name', border: OutlineInputBorder()),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _states.contains(_state) ? _state : 'QLD',
              decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
              items: [for (final s in _states) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() => _state = v ?? _state),
            ),
            const SizedBox(height: 20),
            Text('Centre', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text(
              'Move the map so the pin is on the centre of the city.',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppMap(
                        initialCamera: MapCamera(target: _centre, zoom: 9.5),
                        onCameraIdle: (camera) => setState(() => _centre = camera.target),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: Icon(Icons.location_on, size: 40, color: scheme.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_centre.latitude.toStringAsFixed(4)}, ${_centre.longitude.toStringAsFixed(4)}',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 20),
            Text(
              'Radius: ${_radiusKm.round()} km',
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            Text(
              'Providers within this distance of the centre are listed for the city.',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            Slider(
              value: _radiusKm.clamp(_minRadiusKm, _maxRadiusKm),
              min: _minRadiusKm,
              max: _maxRadiusKm,
              divisions: 99,
              label: '${_radiusKm.round()} km',
              onChanged: (v) => setState(() => _radiusKm = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_isNew ? 'Add city' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
