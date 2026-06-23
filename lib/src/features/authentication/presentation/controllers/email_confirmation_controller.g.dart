// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_confirmation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmailConfirmationController)
final emailConfirmationControllerProvider =
    EmailConfirmationControllerProvider._();

final class EmailConfirmationControllerProvider
    extends $AsyncNotifierProvider<EmailConfirmationController, bool> {
  EmailConfirmationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailConfirmationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailConfirmationControllerHash();

  @$internal
  @override
  EmailConfirmationController create() => EmailConfirmationController();
}

String _$emailConfirmationControllerHash() =>
    r'0242cf2cf21f5413dd854732ac4eca6e0be8b8a4';

abstract class _$EmailConfirmationController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
