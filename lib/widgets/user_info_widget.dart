import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/other_user_profile_screen.dart';

import '../helper/navigation_helper.dart';

class UserInfoWidget extends StatelessWidget {
  final ApiUser user;
  final bool isClickable;

  const UserInfoWidget({
    super.key,
    required this.user,
    this.isClickable = true,
  });

  void _navigateToUserProfile(BuildContext context) {
    if (!isClickable) return;
    NavigationHelper.navigateWithAd(
      context: context,
      destination: OtherUserProfileScreen(
        userId: user.id,
        displayName: user.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isClickable ? () => _navigateToUserProfile(context) : null,
      child: Text(
        '@${user.displayName}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
