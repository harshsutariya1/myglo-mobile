import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/routing/app_router_guard.dart';
import 'package:myglo/src/core/sharing/share_links.dart';

const _id = '3bc82bf3-6504-46f7-a1cc-c4d9a5cfe701';

void main() {
  test('builds public links on the Myglo site', () {
    expect(ShareLinks.post(_id).toString(), 'https://myglo.app/p/$_id');
    expect(ShareLinks.provider(_id).toString(), 'https://myglo.app/provider/$_id');
  });

  test('only exact post and provider links count as shareable', () {
    expect(ShareLinks.isShareable('/p/$_id'), isTrue);
    expect(ShareLinks.isShareable('/provider/$_id'), isTrue);
    expect(ShareLinks.isShareable('/provider/$_id/book'), isFalse);
    expect(ShareLinks.isShareable('/p/not-an-id'), isFalse);
    expect(ShareLinks.isShareable('/appointments/$_id'), isFalse);
  });

  test('a shared post is open to both roles; a shared profile is for clients', () {
    expect(isClientOnlyPath('/p/$_id'), isFalse);
    expect(isProviderOnlyPath('/p/$_id'), isFalse);
    expect(isClientOnlyPath('/provider/$_id'), isTrue);
  });

  test('remembers a shared link until it is taken, once', () {
    final pending = PendingSharedLink()
      ..remember(Uri.parse('https://myglo.app/p/$_id?utm=x'))
      ..remember(Uri.parse('/customer_home'));
    expect(pending.take(), '/p/$_id');
    expect(pending.take(), isNull);
  });
}
