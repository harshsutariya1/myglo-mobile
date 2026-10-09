import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/cover_photos_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/cover_photos_repository.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _url(String name) => 'https://x.supabase.co/storage/v1/object/public/cover-photos/prov-1/$name.jpg';

/// Records what the controller asks of storage and the profile.
class _FakeCovers implements CoverPhotosRepository {
  final saves = <List<String>>[];
  final deleted = <String>[];
  int uploads = 0;
  bool failSaves = false;
  bool failUploads = false;

  @override
  Future<String> upload(String userId, File file) async {
    if (failUploads) throw const SocketException('offline');
    uploads++;
    return _url('new-$uploads');
  }

  @override
  Future<void> save(String userId, List<String> urls) async {
    if (failSaves) throw Exception('save failed');
    saves.add(List.of(urls));
  }

  @override
  Future<void> deleteFiles(Iterable<String> urls) async => deleted.addAll(urls);

  @override
  Future<void> removeUnused(String userId, List<String> keep) async {}
}

Future<(ProviderContainer, _FakeCovers)> _container(List<String> photos, {UserRole role = UserRole.provider}) async {
  final covers = _FakeCovers();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      coverPhotosRepositoryProvider.overrideWithValue(covers),
      userProfileProvider.overrideWith(
        (ref) async => AppUserProfile(
          rawUser: User(
            id: 'prov-1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
          ),
          role: role,
          profile: ProfileModel(id: 'prov-1', role: role, coverPhotos: photos),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(userProfileProvider.future);
  container.listen(coverPhotosControllerProvider, (_, _) {});
  return (container, covers);
}

File _file(String name) => File('/tmp/$name.jpg');

void main() {
  test('starts from the saved photos', () async {
    final (container, _) = await _container([_url('a'), _url('b')]);
    final state = container.read(coverPhotosControllerProvider);
    expect(state.urls, [_url('a'), _url('b')]);
    expect(state.remaining, 3);
  });

  test('adds photos in order and saves after each upload', () async {
    final (container, covers) = await _container([_url('a')]);
    final problem = await container.read(coverPhotosControllerProvider.notifier).add([_file('1'), _file('2')]);

    expect(problem, isNull);
    expect(container.read(coverPhotosControllerProvider).urls, [_url('a'), _url('new-1'), _url('new-2')]);
    expect(covers.saves.last, [_url('a'), _url('new-1'), _url('new-2')]);
  });

  test('never goes past five photos', () async {
    final (container, covers) = await _container([_url('a'), _url('b'), _url('c'), _url('d')]);
    final problem = await container.read(coverPhotosControllerProvider.notifier).add([_file('1'), _file('2'), _file('3')]);

    expect(problem, 'Only 1 more photo fits, so the rest were left out.');
    expect(covers.uploads, 1);
    expect(container.read(coverPhotosControllerProvider).urls, hasLength(5));
    expect(container.read(coverPhotosControllerProvider).remaining, 0);

    final full = await container.read(coverPhotosControllerProvider.notifier).add([_file('4')]);
    expect(full, contains('already have 5'));
    expect(covers.uploads, 1);
  });

  test('a failed upload is dropped with a message', () async {
    final (container, covers) = await _container([]);
    covers.failUploads = true;
    final problem = await container.read(coverPhotosControllerProvider.notifier).add([_file('1')]);

    expect(problem, contains("You're offline"));
    expect(container.read(coverPhotosControllerProvider).slots, isEmpty);
    expect(covers.saves, isEmpty);
  });

  test('if saving a new photo fails, its file is cleaned up', () async {
    final (container, covers) = await _container([]);
    covers.failSaves = true;
    final problem = await container.read(coverPhotosControllerProvider.notifier).add([_file('1')]);

    expect(problem, "We couldn't save your cover photos. Please try again.");
    expect(container.read(coverPhotosControllerProvider).slots, isEmpty);
    expect(covers.deleted, [_url('new-1')]);
  });

  test('removing saves the rest and deletes the file', () async {
    final (container, covers) = await _container([_url('a'), _url('b')]);
    final problem = await container.read(coverPhotosControllerProvider.notifier).remove(_url('a'));

    expect(problem, isNull);
    expect(covers.saves.last, [_url('b')]);
    expect(covers.deleted, [_url('a')]);
  });

  test('a failed removal puts the photo back and keeps the file', () async {
    final (container, covers) = await _container([_url('a'), _url('b')]);
    covers.failSaves = true;
    final problem = await container.read(coverPhotosControllerProvider.notifier).remove(_url('a'));

    expect(problem, isNotNull);
    expect(container.read(coverPhotosControllerProvider).urls, [_url('a'), _url('b')]);
    expect(covers.deleted, isEmpty);
  });

  test('reordering and choosing the main cover save the new order', () async {
    final (container, covers) = await _container([_url('a'), _url('b'), _url('c')]);
    final controller = container.read(coverPhotosControllerProvider.notifier);

    await controller.reorder(0, 2);
    expect(covers.saves.last, [_url('b'), _url('c'), _url('a')]);

    await controller.makeMain(_url('a'));
    expect(covers.saves.last, [_url('a'), _url('b'), _url('c')]);
  });

  test('clients cannot add cover photos', () async {
    final (container, covers) = await _container([], role: UserRole.customer);
    final problem = await container.read(coverPhotosControllerProvider.notifier).add([_file('1')]);

    expect(problem, 'Only providers can add cover photos.');
    expect(covers.uploads, 0);
  });

  test('storage paths come from public URLs only', () {
    expect(CoverPhotosRepository.storagePath('${_url('a')}?t=1'), 'prov-1/a.jpg');
    expect(CoverPhotosRepository.storagePath('https://example.com/a.jpg'), isNull);
  });
}
