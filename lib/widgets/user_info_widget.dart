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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 20,
              backgroundImage: user.profileImageUrl != null || user.photoURL != null
                  ? NetworkImage(user.profileImageUrl ?? user.photoURL!)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              child: (user.profileImageUrl == null && user.photoURL == null)
                  ? Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isClickable)
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.followersCount} followers',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Follow Button
            if (showFollowButton) ...[
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: isFollowLoading ? null : onFollowToggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.isFollow
                        ? Colors.white.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: user.isFollow
                          ? BorderSide(color: Colors.white.withValues(alpha: 0.3))
                          : BorderSide.none,
                    ),
                  ),
                  child: isFollowLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          user.isFollow  ? 'Following' : 'Follow',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}