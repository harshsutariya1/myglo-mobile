// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmailAuthController)
final emailAuthControllerProvider = EmailAuthControllerProvider._();

final class EmailAuthControllerProvider
    extends $AsyncNotifierProvider<EmailAuthController, void> {
  EmailAuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailAuthControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailAuthControllerHash();

  @$internal
  @override
  EmailAuthController create() => EmailAuthController();
}

String _$emailAuthControllerHash() =>
    r'bbf9dbad8f14e615ba43586843d13b2452aa2276';

abstract class _$EmailAuthController extends $AsyncNotifier<void> {
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
