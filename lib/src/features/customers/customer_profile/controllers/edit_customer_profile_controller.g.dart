// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_customer_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EditCustomerProfileController)
final editCustomerProfileControllerProvider =
    EditCustomerProfileControllerProvider._();

final class EditCustomerProfileControllerProvider
    extends $AsyncNotifierProvider<EditCustomerProfileController, void> {
  EditCustomerProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editCustomerProfileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editCustomerProfileControllerHash();

  @$internal
  @override
  EditCustomerProfileController create() => EditCustomerProfileController();
}

String _$editCustomerProfileControllerHash() =>
    r'cb2ca66f66cba906b4536c6fde48cc1d818ff6e8';

abstract class _$EditCustomerProfileController extends $AsyncNotifier<void> {
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
