// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_post_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UploadPostController)
final uploadPostControllerProvider = UploadPostControllerProvider._();

final class UploadPostControllerProvider
    extends $AsyncNotifierProvider<UploadPostController, void> {
  UploadPostControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uploadPostControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uploadPostControllerHash();

  @$internal
  @override
  UploadPostController create() => UploadPostController();
}

String _$uploadPostControllerHash() =>
    r'86944fd8f3562619ee7ade22e19fe22522ab70f0';

abstract class _$UploadPostController extends $AsyncNotifier<void> {
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
