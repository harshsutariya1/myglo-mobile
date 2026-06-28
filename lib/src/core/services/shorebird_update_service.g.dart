// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shorebird_update_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShorebirdUpdateService)
final shorebirdUpdateServiceProvider = ShorebirdUpdateServiceProvider._();

final class ShorebirdUpdateServiceProvider
    extends $NotifierProvider<ShorebirdUpdateService, ShorebirdUpdateState> {
  ShorebirdUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shorebirdUpdateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shorebirdUpdateServiceHash();

  @$internal
  @override
  ShorebirdUpdateService create() => ShorebirdUpdateService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShorebirdUpdateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShorebirdUpdateState>(value),
    );
  }
}

String _$shorebirdUpdateServiceHash() =>
    r'c114bccf67a4ed584bfb9c6488f37aba6d7b4317';

abstract class _$ShorebirdUpdateService
    extends $Notifier<ShorebirdUpdateState> {
  ShorebirdUpdateState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ShorebirdUpdateState, ShorebirdUpdateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShorebirdUpdateState, ShorebirdUpdateState>,
              ShorebirdUpdateState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
