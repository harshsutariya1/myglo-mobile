import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../models/cover_photos_repository.dart';

/// One place in the cover photo list: a saved photo, or one still uploading.
@immutable
class CoverPhotoSlot {
  const CoverPhotoSlot.saved(String this.url)
      : id = url,
        localPath = null;

  const CoverPhotoSlot.uploading({required this.id, required String this.localPath}) : url = null;

  final String id;
  final String? url;

  /// The picked file, shown while it uploads.
  final String? localPath;

  bool get isUploading => url == null;
}

@immutable
class CoverPhotosState {
  const CoverPhotosState({this.slots = const [], this.saving = false});

  final List<CoverPhotoSlot> slots;

  /// A change is being written to the profile.
  final bool saving;

  List<String> get urls => [for (final slot in slots) ?slot.url];

  bool get uploading => slots.any((slot) => slot.isUploading);

  int get remaining => AppConfig.coverPhotosMax - slots.length;

  CoverPhotosState copyWith({List<CoverPhotoSlot>? slots, bool? saving}) =>
      CoverPhotosState(slots: slots ?? this.slots, saving: saving ?? this.saving);
}

final coverPhotosControllerProvider =
    NotifierProvider.autoDispose<CoverPhotosController, CoverPhotosState>(CoverPhotosController.new);

/// Edits the signed-in provider's cover photos. Every change is saved as it
/// happens; each method returns a message to show if something went wrong,
/// or null.
class CoverPhotosController extends Notifier<CoverPhotosState> {
  static const _tag = 'CoverPhotos';

  /// Writes go out one at a time, in order, so a slow save can't land after
  /// a newer one.
  Future<void> _writes = Future.value();
  int _uploadSequence = 0;

  CoverPhotosRepository get _repository => ref.read(coverPhotosRepositoryProvider);

  String? get _userId {
    final user = ref.read(userProfileProvider).value;
    return user != null && user.isProvider ? user.rawUser.id : null;
  }

  @override
  CoverPhotosState build() {
    // Read, not watched: while editing, this list is the source of truth.
    final photos = ref.read(userProfileProvider).value?.profile.coverPhotos ?? const <String>[];
    return CoverPhotosState(slots: [for (final url in photos) CoverPhotoSlot.saved(url)]);
  }

  /// Deletes files from earlier interrupted uploads. Safe to call any time
  /// no upload is running.
  Future<void> tidyUp() async {
    final userId = _userId;
    if (userId == null || state.uploading) return;
    await _repository.removeUnused(userId, state.urls);
  }

  /// Uploads [files] (as many as fit) and adds them after the existing
  /// photos, in the order given.
  Future<String?> add(List<File> files) => _keepAliveWhile(() => _add(files));

  Future<String?> _add(List<File> files) async {
    final userId = _userId;
    if (userId == null) return 'Only providers can add cover photos.';
    if (files.isEmpty) return null;
    final room = state.remaining;
    if (room <= 0) return 'You already have ${AppConfig.coverPhotosMax} cover photos. Remove one to add another.';

    final accepted = files.take(room).toList();
    final pending = [
      for (final file in accepted)
        CoverPhotoSlot.uploading(id: 'upload-${_uploadSequence++}', localPath: file.path),
    ];
    state = state.copyWith(slots: [...state.slots, ...pending]);

    String? problem = files.length > room
        ? 'Only $room more ${room == 1 ? 'photo fits' : 'photos fit'}, so the rest were left out.'
        : null;
    for (var i = 0; i < accepted.length; i++) {
      final slot = pending[i];
      try {
        final url = await _repository.upload(userId, accepted[i]);
        _replace(slot.id, CoverPhotoSlot.saved(url));
        final saved = await _persist();
        if (saved != null) {
          _remove(url);
          await _repository.deleteFiles([url]);
          problem = saved;
        }
      } catch (e, st) {
        _remove(slot.id);
        problem = e is CoverPhotoException ? e.message : _describe(e, action: 'upload a photo');
        if (e is! CoverPhotoException) {
          AppLogger.w('Cover photo upload failed', tag: _tag, error: e, stackTrace: st);
        }
      }
    }
    return problem;
  }

  /// Removes a saved photo from the profile, then deletes its file.
  Future<String?> remove(String url) => _keepAliveWhile(() => _removeSaved(url));

  Future<String?> _removeSaved(String url) async {
    final before = state.slots;
    _remove(url);
    final problem = await _persist();
    if (problem != null) {
      state = state.copyWith(slots: before);
      return problem;
    }
    await _repository.deleteFiles([url]);
    return null;
  }

  /// Moves the photo at [from] to [to] (indices in the current list).
  Future<String?> reorder(int from, int to) => _keepAliveWhile(() => _reorder(from, to));

  Future<String?> _reorder(int from, int to) async {
    if (state.uploading || from == to) return null;
    final before = state.slots;
    final slots = [...before];
    final moved = slots.removeAt(from);
    slots.insert(to.clamp(0, slots.length), moved);
    state = state.copyWith(slots: slots);
    final problem = await _persist();
    if (problem != null) state = state.copyWith(slots: before);
    return problem;
  }

  /// Makes [url] the main (first) cover photo.
  Future<String?> makeMain(String url) {
    final index = state.slots.indexWhere((slot) => slot.url == url);
    return index <= 0 ? Future.value(null) : reorder(index, 0);
  }

  /// Finishes [operation] (and its save) even if the screen closes midway,
  /// so the profile isn't left half-updated.
  Future<T> _keepAliveWhile<T>(Future<T> Function() operation) async {
    final link = ref.keepAlive();
    try {
      return await operation();
    } finally {
      link.close();
    }
  }

  void _replace(String id, CoverPhotoSlot slot) {
    state = state.copyWith(slots: [for (final existing in state.slots) existing.id == id ? slot : existing]);
  }

  void _remove(String id) {
    state = state.copyWith(slots: [for (final existing in state.slots) if (existing.id != id) existing]);
  }

  /// Saves the current saved photos in order. Returns a message on failure.
  Future<String?> _persist() {
    final userId = _userId;
    if (userId == null) return Future.value('Only providers can change cover photos.');
    final urls = state.urls;
    final result = _writes.then((_) async {
      state = state.copyWith(saving: true);
      try {
        await _repository.save(userId, urls);
        ref.invalidate(userProfileProvider);
        return null;
      } catch (e) {
        return _describe(e, action: 'save your cover photos');
      } finally {
        state = state.copyWith(saving: false);
      }
    });
    _writes = result.then((_) {});
    return result;
  }

  static String _describe(Object error, {required String action}) => isConnectivityError(error)
      ? "You're offline, so we couldn't $action. Check your connection and try again."
      : "We couldn't $action. Please try again.";
}
