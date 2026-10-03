import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../../shared/authentication/models/user_role.dart';

/// Fallback label when a post's author can't be shown.
const String postAuthorFallbackName = 'Myglo member';

/// Name shown for a post's author: the business name for providers,
/// otherwise the person's name.
String postAuthorName(ProfileModel profile) {
  final business = profile.providerName?.trim() ?? '';
  if (profile.role == UserRole.provider && business.isNotEmpty) return business;
  final name = '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();
  return name.isNotEmpty ? name : (business.isNotEmpty ? business : postAuthorFallbackName);
}

/// Round profile photo, or the author's initial when they have none.
class PostAuthorAvatar extends StatelessWidget {
  const PostAuthorAvatar({super.key, required this.profile, required this.radius});

  /// Null shows a neutral placeholder (unknown or deleted account).
  final ProfileModel? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final profile = this.profile;
    final url = profile?.profilePic;
    if (profile == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
        child: Icon(Icons.person_rounded, size: radius, color: scheme.onSurface.withValues(alpha: 0.4)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
      child: url == null
          ? Text(
              postAuthorName(profile).characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700, color: scheme.onPrimary),
            )
          : null,
    );
  }
}

/// White heart that pops and fades over media after a double-tap like.
/// Give it a new key to replay.
class HeartBurst extends StatelessWidget {
  const HeartBurst({super.key, required this.visible, this.size = 96});

  final bool visible;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 750),
      builder: (context, t, child) {
        final scale = t < 0.35 ? Curves.easeOutBack.transform(t / 0.35) : 1.0;
        final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
      child: Icon(
        Icons.favorite_rounded,
        size: size,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black38, blurRadius: 18)],
      ),
    );
  }
}

/// Page indicator for a media carousel; the active page is a wider pill.
class MediaDots extends StatelessWidget {
  const MediaDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == index ? 1 : 0.55),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
      ],
    );
  }
}
