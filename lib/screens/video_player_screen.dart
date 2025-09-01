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

  void _modifyVideo(String videoId, ApiVideo? Function(ApiVideo video) modifyFn) {
    bool changed = false;

    void updateList(List<ApiVideo> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i != -1) {
        final newVideo = modifyFn(list[i]);
        if (newVideo == null) {
          list.removeAt(i);
        } else {
          list[i] = newVideo;
        }
        changed = true;
      }
    }

    updateList(_videos);

    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(true);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildVideo(),
              Positioned(
                top: 16,
                left: 16,
                child: _buildBackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return PageView.builder(
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
          onVideoDeleted: (deletedVideo) {
            setState(() {
              print('Video deleted: ${deletedVideo.id}');
              _videos.removeWhere((v) => v.id == deletedVideo.id);

              if (_videos.isEmpty) {
                Navigator.of(context).pop(deletedVideo.id);
              } else if (_currentIndex >= _videos.length) {
                _currentIndex = _videos.length - 1;
              }
            });
          },
          onLikeUpdated: (newCount, isLiked) => _modifyVideo(video.id, (v) {
            return v.copyWith(likesCount: newCount, isLiked: isLiked,);
          }),
          onCommentUpdated: (newCount) => _modifyVideo(video.id, (v) {
            return v.copyWith(commentsCount: newCount,);
          }),
          onReported: (reportedVideo) => _modifyVideo(reportedVideo.id, (_) => null),
          onFollowUpdated: (updatedUser) => _modifyVideo(video.id, (v) {
            return v.copyWith(user: updatedUser);
          }),
          onPauseRequested: () => setScreenVisible(false),
          onResumeRequested: () => setScreenVisible(true),
        );
      },
    );
  }

  Widget _buildBackButton() {
    return Container(
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
    );
  }

}
