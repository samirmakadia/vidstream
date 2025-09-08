import 'package:flutter/material.dart';
import '../models/api_models.dart';
import '../widgets/custom_image_widget.dart';

class VideoGridItemWidget extends StatelessWidget {
  final ApiVideo video;
  final VoidCallback onTap;
  final double borderRadius;

  const VideoGridItemWidget({
    super.key,
    required this.video,
    required this.onTap,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbnail(),
            _buildPlayIcon(context),
            _buildStatsBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomImageWidget(
        imageUrl: video.thumbnailUrl,
        height: double.infinity,
        width: double.infinity,
        cornerRadius: borderRadius,
      ),
    );
  }

  Widget _buildPlayIcon(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    return Positioned(
      bottom: 6,
      left: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStat(Icons.favorite, Colors.red, video.likesCount, context),
            _buildStat(Icons.visibility, Colors.blue, video.viewsCount, context),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, Color color, int count, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
