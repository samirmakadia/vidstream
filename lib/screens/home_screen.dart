import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/search_screen.dart';
import 'package:vidstream/utils/utils.dart';
import 'dart:async';
import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../services/socket_manager.dart';
import 'home/bottomsheet/filter_bottom_sheet.dart';
import 'home/widget/video_feed_item_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  List<ApiVideo> _videos = [];
  List<ApiVideo> _allVideos = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  List<String> _selectedTags = [];
  bool _isScreenVisible = true;
  late StreamSubscription _videoUploadedSubscription;

  @override
  bool get wantKeepAlive => true;

  void setScreenVisible(bool isVisible) {
    if (mounted && _isScreenVisible != isVisible) {
      setState(() {
        _isScreenVisible = isVisible;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
    _videoUploadedSubscription = eventBus.on().listen((event) {
      if (event == 'updatedVideo') {
        print('A new video was uploaded!');
        _loadVideos(isLoadingShow: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }


  Future<void> _loadVideos({bool isLoadingShow = true}) async {
    if(isLoadingShow) {
      setState(() => _isLoading = true);
    }
    try {
      final videos = await ApiRepository.instance.videos.getVideosOnce();
      setState(() {
        _videos = videos;
        _allVideos = videos;
        _isLoading = false;
      });
      print('Loaded home ${videos.length} videos');

    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load videos: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshVideos() async {
    await _loadVideos();
  }

  void _openSearchScreen() {
    NavigationHelper.navigateWithAd(
      context: context,
      destination: const SearchScreen(),
    );
  }

  void _applyFilter() {
    if (_selectedTags.isEmpty) {
      setState(() {
        _videos = _allVideos;
        _currentIndex = 0;
      });
    } else {
      final filtered = _allVideos.where((video) {
        return _selectedTags.any((tag) =>
            video.tags.any((videoTag) => videoTag.toLowerCase() == tag.toLowerCase()));
      }).toList();

      setState(() {
        _videos = filtered;
        _currentIndex = 0;
      });
    }

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _videos = _allVideos;
      _currentIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _showFilterDialog() async {
    setScreenVisible(false);

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        selectedTags: _selectedTags,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedTags = result;
      });
      _applyFilter();
    }

    setScreenVisible(true);
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
    updateList(_allVideos);

    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : _videos.isEmpty
              ? _buildEmptyState()
              : _buildFeedView(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildTopActionBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _openSearchScreen,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.search,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),

        GestureDetector(
          onTap: _showFilterDialog,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedTags.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.filter_list,
                  color: _selectedTags.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  size: 20,
                ),
                if (_selectedTags.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_selectedTags.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildFeedView() {
    const int videosPerAd = 4;
    final showAds = AppLovinAdManager.isNativeAdLoaded;
    final loadedVideos = _videos;

    final totalAds = showAds ? (loadedVideos.length / videosPerAd).floor() : 0;
    final totalItems = loadedVideos.length + totalAds;

    return RefreshIndicator(
      onRefresh: _refreshVideos,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: totalItems,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final isAdIndex = showAds && (index + 1) % (videosPerAd + 1) == 0;

          if (isAdIndex) {
            return SizedBox.expand(
              child: AppLovinAdManager.nativeAdLarge(
                height: Utils(context).screenHeight,
              ),
            );
          }

          final videoIndex = showAds
              ? index - (index ~/ (videosPerAd + 1))
              : index;

          if (videoIndex >= loadedVideos.length) return const SizedBox.shrink();

          final video = loadedVideos[videoIndex];

          return VideoFeedItemWidget(
            key: ValueKey(video.id),
            video: video,
            isActive: index == _currentIndex && _isScreenVisible,
            onVideoCompleted: () {
              if (_pageController.hasClients) {
                final nextPage = (_currentIndex + 1) % _videos.length;
                _pageController.animateToPage(
                  nextPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            onVideoDeleted: (deletedVideo) {
              _modifyVideo(video.id, (_) => null);
            },
            onLikeUpdated: (newCount, isLiked) =>
                _modifyVideo(video.id, (v) => v.copyWith(
                  likesCount: newCount,
                  isLiked: isLiked,
                )),
            onCommentUpdated: (newCount) =>
                _modifyVideo(video.id, (v) => v.copyWith(commentsCount: newCount)),
            onReported: (reportedVideo) =>
                _modifyVideo(reportedVideo.id, (_) => null),
            onFollowUpdated: (updatedUser) =>
                _modifyVideo(video.id, (v) => v.copyWith(user: updatedUser)),
            onPauseRequested: () => setScreenVisible(false),
            onResumeRequested: () => setScreenVisible(true),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
             _selectedTags.isNotEmpty
                ? Icons.search_off
                : Icons.video_library_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
             _selectedTags.isNotEmpty
                ? 'No videos found'
                : 'No videos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
             _selectedTags.isNotEmpty
                ? 'Try different keywords or filters'
                : 'Be the first to share a video!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedTags.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                _clearFilters();
              },
              icon: const Icon(Icons.clear),
              label: Text('Clear Search',style: TextStyle(color: Colors.black),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _refreshVideos,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh',style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

