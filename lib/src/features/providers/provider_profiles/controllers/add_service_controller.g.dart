// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_service_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AddServiceController)
final addServiceControllerProvider = AddServiceControllerProvider._();

final class AddServiceControllerProvider
    extends $AsyncNotifierProvider<AddServiceController, void> {
  AddServiceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addServiceControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addServiceControllerHash();

  @$internal
  @override
  AddServiceController create() => AddServiceController();
}

String _$addServiceControllerHash() =>
    r'522221ac0e140b45404a1591a67833af8bfe03ce';

abstract class _$AddServiceController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
