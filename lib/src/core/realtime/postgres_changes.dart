import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A signal from Supabase Realtime: a row changed, or the channel
/// (re)connected and anything may have been missed while it was down.
class RealtimeChange {
  const RealtimeChange(this.payload);

  const RealtimeChange.resync() : payload = null;

  final PostgresChangePayload? payload;

  bool get isResync => payload == null;
}

int _channelSequence = 0;

/// Postgres changes on [table] matching [filter], as a stream.
///
/// Emits [RealtimeChange.resync] every time the channel (re)subscribes so
/// listeners can refetch whatever they missed while disconnected; the
/// realtime client retries dropped connections on its own. The channel is
/// removed when the listener cancels. Row level security decides which rows a
/// user hears about.
Stream<RealtimeChange> watchPostgresChanges(
  SupabaseClient client, {
  required String table,
  PostgresChangeFilter? filter,
  PostgresChangeEvent event = PostgresChangeEvent.all,
}) {
  late final StreamController<RealtimeChange> controller;
  RealtimeChannel? channel;

  controller = StreamController<RealtimeChange>(
    onListen: () {
      // Unique per subscription so two screens watching the same rows don't
      // share (and tear down) one channel.
      final name = 'db-$table-${_channelSequence++}';
      channel = client
          .channel(name)
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: table,
            filter: filter,
            callback: (payload) {
              if (!controller.isClosed) controller.add(RealtimeChange(payload));
            },
          )
          .subscribe((status, error) {
            switch (status) {
              case RealtimeSubscribeStatus.subscribed:
                if (!controller.isClosed) controller.add(const RealtimeChange.resync());
              case RealtimeSubscribeStatus.channelError:
              case RealtimeSubscribeStatus.timedOut:
                Sentry.addBreadcrumb(Breadcrumb(
                  category: 'realtime',
                  message: '$table channel ${status.name}${error == null ? '' : ': $error'}',
                  level: SentryLevel.warning,
                ));
              case RealtimeSubscribeStatus.closed:
                break;
            }
          });
    },
    onCancel: () async {
      final current = channel;
      channel = null;
      if (current != null) await client.removeChannel(current);
    },
  );
  return controller.stream;
}
