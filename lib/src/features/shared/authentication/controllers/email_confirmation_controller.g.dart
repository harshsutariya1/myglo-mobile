// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'email_confirmation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives account creation with an emailed verification code.
///
/// The state is `true` once a code has been sent. Verifying and resending do
/// not change the state, so the code-entry UI stays on screen while they run
/// (the screen tracks their busy flags itself). Errors are thrown to the
/// caller, which maps them to user-facing text.

@ProviderFor(EmailConfirmationController)
final emailConfirmationControllerProvider =
    EmailConfirmationControllerProvider._();

/// Drives account creation with an emailed verification code.
///
/// The state is `true` once a code has been sent. Verifying and resending do
/// not change the state, so the code-entry UI stays on screen while they run
/// (the screen tracks their busy flags itself). Errors are thrown to the
/// caller, which maps them to user-facing text.
final class EmailConfirmationControllerProvider
    extends $AsyncNotifierProvider<EmailConfirmationController, bool> {
  /// Drives account creation with an emailed verification code.
  ///
  /// The state is `true` once a code has been sent. Verifying and resending do
  /// not change the state, so the code-entry UI stays on screen while they run
  /// (the screen tracks their busy flags itself). Errors are thrown to the
  /// caller, which maps them to user-facing text.
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
    r'fb7c4e254242810c54f81704643dfee61af8c7ee';

/// Drives account creation with an emailed verification code.
///
/// The state is `true` once a code has been sent. Verifying and resending do
/// not change the state, so the code-entry UI stays on screen while they run
/// (the screen tracks their busy flags itself). Errors are thrown to the
/// caller, which maps them to user-facing text.

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
