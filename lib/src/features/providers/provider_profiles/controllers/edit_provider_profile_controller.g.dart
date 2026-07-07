// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_provider_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EditProviderProfileController)
final editProviderProfileControllerProvider =
    EditProviderProfileControllerProvider._();

final class EditProviderProfileControllerProvider
    extends $AsyncNotifierProvider<EditProviderProfileController, void> {
  EditProviderProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editProviderProfileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editProviderProfileControllerHash();

  @$internal
  @override
  EditProviderProfileController create() => EditProviderProfileController();
}

String _$editProviderProfileControllerHash() =>
    r'308d4141b868b69cb1462e62043cbe665c7f5ee1';

abstract class _$EditProviderProfileController extends $AsyncNotifier<void> {
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
