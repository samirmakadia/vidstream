import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'home/widget/video_feed_item_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final ApiVideo video;
  final List<ApiVideo> allVideos;
  final ApiUser? user;

  const VideoPlayerScreen({
    super.key,
    this.user,
    required this.video,
    required this.allVideos,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with AutomaticKeepAliveClientMixin{
  late PageController _pageController;
  late List<ApiVideo> _videos;
  int _currentIndex = 0;
  bool _isScreenVisible = true;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.allVideos);
    final initialIndex = _videos.indexWhere((v) => v.id == widget.video.id);
    _currentIndex = initialIndex != -1 ? initialIndex : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setScreenVisible(bool isVisible) {
    if (mounted && _isScreenVisible != isVisible) {
      setState(() {
        _isScreenVisible = isVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final video = _videos[index];
                return VideoFeedItemWidget(
                  video: video,
                  isActive: index == _currentIndex && _isScreenVisible,
                  user: widget.user,
                  onVideoDeleted: () {
                    setState(() {
                      _videos.removeAt(index);
                      if (_videos.isEmpty) {
                        Navigator.of(context).pop();
                      } else if (index <= _currentIndex && _currentIndex > 0) {
                        _currentIndex--;
                      }
                    });
                  },
                  onPauseRequested: () => setScreenVisible(false),
                  onResumeRequested: () => setScreenVisible(true),
                );
              },
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
