import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/other_user_profile_screen.dart';

class UserInfoWidget extends StatelessWidget {
  final ApiUser user;
  final VoidCallback onFollowToggle;
  final bool showFollowButton;
  final bool isFollowLoading;
  final bool isClickable;

  const UserInfoWidget({
    super.key,
    required this.user,
    required this.onFollowToggle,
    this.showFollowButton = true,
    this.isFollowLoading = false,
    this.isClickable = true,
  });

  void _navigateToUserProfile(BuildContext context) {
    if (!isClickable) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: user.id,
          displayName: user.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isClickable ? () => _navigateToUserProfile(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
        Text(
          '@${user.displayName}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
