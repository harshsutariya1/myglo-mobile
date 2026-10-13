import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/utils/formatters.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/views/widgets/booking_card.dart';
import 'package:myglo/src/features/shared/reviews/controllers/reviews_controllers.dart';
import 'package:myglo/src/features/shared/reviews/models/review.dart';
import 'package:myglo/src/features/shared/reviews/models/review_failure.dart';
import 'package:myglo/src/features/shared/reviews/models/review_summary.dart';
import 'package:myglo/src/features/shared/reviews/models/reviews_repository.dart';
import 'package:myglo/src/features/shared/reviews/views/review_composer_screen.dart';
import 'package:myglo/src/features/shared/reviews/views/widgets/booking_review_section.dart';
import 'package:myglo/src/features/shared/reviews/views/widgets/rating_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

class _MockReviews extends Mock implements ReviewsRepository {}

class _MockPosts extends Mock implements PostRepository {}

final _client = AppUserProfile(
  rawUser: User(
    id: 'client-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: UserRole.customer,
  profile: const ProfileModel(id: 'client-1', role: UserRole.customer, firstName: 'Michelle'),
);

Review _review({int rating = 5, List<String> photos = const [], String? reply}) => Review(
      id: 'review-1',
      bookingId: 'booking-1',
      providerId: 'prov-1',
      clientId: 'client-1',
      reviewerName: 'Michelle Z.',
      rating: rating,
      body: 'Loved my lashes',
      serviceNames: const ['Lash lift', 'Lash tint'],
      photoUrls: photos,
      postId: photos.isEmpty ? null : 'post-9',
      reply: reply,
      repliedAt: reply == null ? null : DateTime.utc(2026, 10, 9),
      createdAt: DateTime.utc(2026, 10, 8),
    );

const _url = 'https://x.supabase.co/storage/v1/object/public/post-media/client-1/';

void main() {
  setUpAll(() {
    registerFallbackValue(File('fallback.jpg'));
  });

  group('models', () {
    test('reads a list_reviews row', () {
      final review = Review.fromJson({
        'id': 'r',
        'booking_id': 'b',
        'provider_id': 'p',
        'client_id': 'c',
        'reviewer_name': 'Mia T.',
        'reviewer_avatar_url': null,
        'rating': 4,
        'body': '  ',
        'service_ids': ['s1'],
        'service_names': ['Lash lift', ''],
        'photo_urls': ['${_url}a.jpg'],
        'post_id': 'post',
        'reply': null,
        'replied_at': null,
        'edited_at': '2026-10-10T01:00:00+00:00',
        'created_at': '2026-10-09T01:00:00+00:00',
      });
      expect(review.rating, 4);
      expect(review.body, isNull, reason: 'blank text is no text');
      expect(review.serviceNames, ['Lash lift']);
      expect(review.photoUrls, hasLength(1));
      expect(review.isEdited, isTrue);
      expect(review.hasReply, isFalse);
    });

    test('summaries read stats rows and treat zero reviews as empty', () {
      final summary = ReviewSummary.fromJson({
        'review_count': 3,
        'rating_average': 4.67,
        'stars_1': 0,
        'stars_2': 0,
        'stars_3': 0,
        'stars_4': 1,
        'stars_5': 2,
      });
      expect(summary.isEmpty, isFalse);
      expect(summary.countFor(5), 2);
      expect(ratingLineText(summary), '4.7 (3 reviews)');

      final none = ReviewSummary.fromJson({'review_count': 0, 'rating_average': null});
      expect(none.isEmpty, isTrue);
      expect(ratingLineText(none), 'New · No reviews yet');
    });

    test('ratings format to one decimal and stay within 1–5', () {
      expect(Formatters.rating(4.75), '4.8');
      expect(Formatters.rating(5), '5.0');
      expect(Formatters.rating(0.2), '1.0');
      expect(Formatters.reviewCount(1), '1 review');
      expect(Formatters.reviewCount(1200), '1.2k reviews');
    });

    test('server refusals become readable failures; outages are offline', () {
      final refused = ReviewFailure.from(const PostgrestException(message: 'booking_not_completed', code: 'P0001'));
      expect(refused.code, ReviewFailureCode.bookingNotCompleted);
      expect(refused.isExpected, isTrue);
      expect(refused.message, contains('completed'));

      expect(ReviewFailure.from(const SocketException('down')).code, ReviewFailureCode.offline);
      expect(ReviewFailure.from(StateError('bug')).isExpected, isFalse);
    });
  });

  group('ReviewActions.submit', () {
    late _MockReviews reviews;
    late _MockPosts posts;
    late ProviderContainer container;

    setUp(() {
      reviews = _MockReviews();
      posts = _MockPosts();
      container = ProviderContainer.test(
        overrides: [
          userProfileProvider.overrideWith((ref) async => _client),
          reviewsRepositoryProvider.overrideWithValue(reviews),
          postRepositoryProvider.overrideWithValue(posts),
        ],
      );
      when(() => posts.removeMedia(any())).thenAnswer((_) async {});
      when(() => posts.uploadPostMedia(any(), any())).thenAnswer((call) async {
        final file = call.positionalArguments[1] as File;
        return '$_url${file.uri.pathSegments.last}';
      });
      when(() => reviews.submit(
            bookingId: any(named: 'bookingId'),
            rating: any(named: 'rating'),
            body: any(named: 'body'),
            photoUrls: any(named: 'photoUrls'),
          )).thenAnswer((_) async => 'review-1');
    });

    test('uploads new photos after the kept ones and deletes the removed ones', () async {
      await container.read(userProfileProvider.future);
      await container.read(reviewActionsProvider).submit(
            bookingId: 'booking-1',
            providerId: 'prov-1',
            rating: 5,
            body: '  Great  ',
            originalPhotoUrls: ['${_url}old-1.jpg', '${_url}old-2.jpg'],
            keptPhotoUrls: ['${_url}old-2.jpg'],
            newPhotos: [File('new-1.jpg')],
          );

      verify(() => reviews.submit(
            bookingId: 'booking-1',
            rating: 5,
            body: 'Great',
            photoUrls: ['${_url}old-2.jpg', '${_url}new-1.jpg'],
          )).called(1);
      verify(() => posts.removeMedia(['${_url}old-1.jpg'])).called(1);
    });

    test('leaves photos alone when they did not change', () async {
      await container.read(userProfileProvider.future);
      await container.read(reviewActionsProvider).submit(
            bookingId: 'booking-1',
            providerId: 'prov-1',
            rating: 3,
            body: '',
            originalPhotoUrls: ['${_url}a.jpg'],
            keptPhotoUrls: ['${_url}a.jpg'],
          );

      verify(() => reviews.submit(bookingId: 'booking-1', rating: 3, body: null, photoUrls: null)).called(1);
      verifyNever(() => posts.uploadPostMedia(any(), any()));
      verifyNever(() => posts.removeMedia(any()));
    });

    test('a refused review removes the photos it just uploaded', () async {
      when(() => reviews.submit(
            bookingId: any(named: 'bookingId'),
            rating: any(named: 'rating'),
            body: any(named: 'body'),
            photoUrls: any(named: 'photoUrls'),
          )).thenThrow(const ReviewFailure(ReviewFailureCode.bookingNotCompleted));
      await container.read(userProfileProvider.future);

      await expectLater(
        container.read(reviewActionsProvider).submit(
              bookingId: 'booking-1',
              providerId: 'prov-1',
              rating: 5,
              body: 'x',
              newPhotos: [File('fresh.jpg')],
            ),
        throwsA(isA<ReviewFailure>().having((f) => f.code, 'code', ReviewFailureCode.bookingNotCompleted)),
      );
      verify(() => posts.removeMedia(['${_url}fresh.jpg'])).called(1);
    });

    test('refuses more photos than allowed before uploading anything', () async {
      await container.read(userProfileProvider.future);
      await expectLater(
        container.read(reviewActionsProvider).submit(
              bookingId: 'booking-1',
              providerId: 'prov-1',
              rating: 5,
              body: '',
              newPhotos: [for (var i = 0; i < 5; i++) File('p$i.jpg')],
            ),
        throwsA(isA<ReviewFailure>().having((f) => f.code, 'code', ReviewFailureCode.tooManyPhotos)),
      );
      verifyNever(() => posts.uploadPostMedia(any(), any()));
    });
  });

  group('booking review section', () {
    Future<void> pump(WidgetTester tester, Widget child, {List<Review> reviews = const []}) async {
      final repository = _MockReviews();
      when(() => repository.list(
            providerId: any(named: 'providerId'),
            serviceId: any(named: 'serviceId'),
            bookingId: any(named: 'bookingId'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => reviews);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            userProfileProvider.overrideWith((ref) async => _client),
            reviewsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: child))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a completed booking invites a rating; others show nothing', (tester) async {
      await pump(tester, ClientBookingReviewSection(booking: sampleBooking(status: BookingStatus.completed)));
      expect(find.text('How was your visit?'), findsOneWidget);

      await pump(tester, ClientBookingReviewSection(booking: sampleBooking(status: BookingStatus.cancelled)));
      expect(find.text('How was your visit?'), findsNothing);
    });

    testWidgets('a reviewed booking shows the review with an edit button', (tester) async {
      await pump(
        tester,
        ClientBookingReviewSection(
          booking: sampleBooking(status: BookingStatus.completed, reviewId: 'review-1', reviewRating: 5),
        ),
        reviews: [_review(reply: 'See you soon!')],
      );
      expect(find.text('Your review'), findsOneWidget);
      expect(find.text('Loved my lashes'), findsOneWidget);
      expect(find.text('Edit review'), findsOneWidget);
      expect(find.text('See you soon!'), findsOneWidget);
    });

    testWidgets("the provider sees the client's review and can reply", (tester) async {
      await pump(
        tester,
        ProviderBookingReviewSection(
          booking: sampleBooking(status: BookingStatus.completed, reviewId: 'review-1', reviewRating: 5),
        ),
        reviews: [_review()],
      );
      expect(find.text("Michelle Zhang's review"), findsOneWidget);
      expect(find.text('Reply publicly'), findsOneWidget);
    });

    testWidgets('a booking card footer stays reachable by screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BookingCard(
              booking: sampleBooking(status: BookingStatus.completed),
              onTap: () {},
              footer: OutlinedButton(onPressed: () {}, child: const Text('Rate & review')),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Rate & review'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Lash lift, Lash tint with Glow Studio')), findsOneWidget);
      semantics.dispose();
    });
  });

  group('composer', () {
    testWidgets('posting needs a star rating, then saves the review', (tester) async {
      final reviews = _MockReviews();
      when(() => reviews.submit(
            bookingId: any(named: 'bookingId'),
            rating: any(named: 'rating'),
            body: any(named: 'body'),
            photoUrls: any(named: 'photoUrls'),
          )).thenAnswer((_) async => 'review-1');
      final booking = sampleBooking(status: BookingStatus.completed);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            userProfileProvider.overrideWith((ref) async => _client),
            reviewsRepositoryProvider.overrideWithValue(reviews),
            postRepositoryProvider.overrideWithValue(_MockPosts()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openReviewComposer(context, booking: booking),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final post = find.widgetWithText(FilledButton, 'Post review');
      expect(tester.widget<FilledButton>(post).onPressed, isNull);
      // Photos are public, so the client is told before adding any.
      expect(find.textContaining('shared publicly on Discover'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^4 stars')));
      await tester.pump();
      expect(find.text('Great'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Lovely lift');
      await tester.pump();
      await tester.tap(post);
      await tester.pumpAndSettle();

      verify(() => reviews.submit(bookingId: 'booking-1', rating: 4, body: 'Lovely lift', photoUrls: null)).called(1);
      expect(find.text('Thanks! Your review is live.'), findsOneWidget);
    });
  });
}
