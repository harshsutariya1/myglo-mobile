// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_post_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeletePostController)
final deletePostControllerProvider = DeletePostControllerProvider._();

final class DeletePostControllerProvider
    extends $AsyncNotifierProvider<DeletePostController, void> {
  DeletePostControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deletePostControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deletePostControllerHash();

  @$internal
  @override
  DeletePostController create() => DeletePostController();
}

String _$deletePostControllerHash() =>
    r'b3bc13ab9113b8849869ff4c9fde70061173a9a3';

abstract class _$DeletePostController extends $AsyncNotifier<void> {
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
