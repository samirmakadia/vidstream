import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/screens/search_screen.dart';
import 'package:vidmeet/utils/utils.dart';
import 'dart:async';
import '../helper/navigation_helper.dart';
import '../manager/applovin_ad_manager.dart';
import '../manager/setting_manager.dart';
import '../services/socket_manager.dart';
import '../utils/graphics.dart';
import '../widgets/circular_icon_button.dart';
import '../widgets/empty_section.dart';
import 'home/widget/video_feed_item_widget.dart';
import 'package:better_player_plus/better_player_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool get _canPrecache => Platform.isAndroid;
  final PageController _pageController = PageController();
  late StreamSubscription _videoUploadedSubscription;
  late BetterPlayerController _precacheController;
  final Map<int, BetterPlayerController> _preparedControllers = {};
  final Set<int> _preparingControllers = {};
  final Set<String> _precaching = {};
  List<ApiVideo> _videos = [];
  List<ApiVideo> _allVideos = [];
  final List<String> _selectedTags = [];
  bool _isScreenVisible = true;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _currentIndex = 0;
  final int _pageSize = 20;
  bool _isAuto  = true;

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
    _loadVideos(isRefresh: true);
    if (_canPrecache) {
      _precacheController = BetterPlayerController(
        const BetterPlayerConfiguration(autoPlay: false),
      );
    }
    updateEventSubscription();
  }

  void updateEventSubscription() {
    _videoUploadedSubscription = eventBus.on().listen((event) {
      if (event is Map<String, dynamic>) {
        if (event['type'] == 'updatedVideo') {
          if (event['source'] != 'fromHome') {
             _loadVideos(isLoadingShow: true, isRefresh: true);
          }
        } else {
          final userId = event["userId"];
          final isFollow = event["isFollow"];
          if (userId != null && isFollow != null) {
            _updateFollowStatus(_videos, userId, isFollow);
            _updateFollowStatus(_allVideos, userId, isFollow);
          }
        }
      }
    });
  }

  void _updateFollowStatus(List<ApiVideo> videos, String userId, bool isFollow) {
    for (var i = 0; i < videos.length; i++) {
      final video = videos[i];
      if (video.user?.id == userId) {
        videos[i] = video.copyWith(
          user: video.user!.copyWith(isFollow: isFollow),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_canPrecache) {
      for (var url in _precaching.toList()) {
        _stopPrecache(url);
      }
      _precacheController.dispose();
    }
    _pageController.dispose();
    _videoUploadedSubscription.cancel();
    _clearPreparedControllers();
    super.dispose();
  }

  BetterPlayerDataSource _makeDS(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(
        minBufferMs: 2000,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 500,
        bufferForPlaybackAfterRebufferMs: 1000,
      ),
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: 5 * 1024 * 1024,
        maxCacheSize: 500 * 1024 * 1024,
        maxCacheFileSize: 50 * 1024 * 1024,
      ),
    );
  }

  Future<void> _startPrecache(String url) async {
    if (!_canPrecache) return;
    if (_precaching.contains(url)) return;
    try {
      _precaching.add(url);
      await _precacheController.preCache(_makeDS(url));
      debugPrint("✅ precached $url");
    } catch (e) {
      debugPrint("⚠️ precache failed $url: $e");
      _precaching.remove(url);
    }
  }

  Future<void> _stopPrecache(String url) async {
    if (!_canPrecache) return;
    if (!_precaching.contains(url)) return;
    try {
      await _precacheController.stopPreCache(_makeDS(url));
    } catch (_) {}
    _precaching.remove(url);
  }

  Future<void> _prepareControllerAt(int index) async {
    if (index < 0 || index >= _videos.length) return;
    if (_preparedControllers.containsKey(index)) return;
    if (_preparingControllers.contains(index)) return;
    _preparingControllers.add(index);
    try {
      final url = _videos[index].videoUrl;
      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          looping: !_isAuto,
          handleLifecycle: true,
          expandToFill: true,
          fit: BoxFit.contain,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false,
          ),
        ),
      );
      await controller.setupDataSource(_makeDS(url));
      final aspect = controller.videoPlayerController!.value.aspectRatio;
      controller.setOverriddenAspectRatio(aspect);
      await controller.pause();
      _preparedControllers[index] = controller;
      if (mounted) setState(() {});
    } catch (_) {
      // ignore prep failure; widget will initialize on demand
    } finally {
      _preparingControllers.remove(index);
    }
  }

  void _disposePreparedAt(int index) {
    final c = _preparedControllers.remove(index);
    c?.dispose();
    if (mounted) setState(() {});
  }

  void _clearPreparedControllers({bool immediate = false}) {
    final toDispose = _preparedControllers.values.toList();
    _preparedControllers.clear();
    _preparingControllers.clear();
    if (immediate) {
      for (final c in toDispose) {
        c.dispose();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 400), () {
        for (final c in toDispose) {
          try { c.dispose(); } catch (_) {}
        }
      });
    }
  }

  void _prepareControllersAround(int center) {
    _prepareControllerAt(center - 1);
    _prepareControllerAt(center + 1);
    _prepareControllerAt(center + 2);
  }

  int _currentLogicalIndex() {
    final videosPerAd = SettingManager().nativeFrequency;
    final showAds = AppLovinAdManager.isMrecAdLoaded;
    return showAds
        ? _currentIndex - (_currentIndex ~/ (videosPerAd + 1))
        : _currentIndex;
  }

  bool _shouldKeepIndex(int center, int idx) {
    return idx == center || idx == center - 1 || idx == center + 1 || idx == center + 2;
  }

  void _cleanupPreparedNotNeeded(int center) {
    final keep = <int>{center - 1, center, center + 1, center + 2};
    for (final idx in _preparedControllers.keys.toList()) {
      if (!keep.contains(idx)) {
        Future.delayed(const Duration(milliseconds: 350), () {
          final currentCenter = _currentLogicalIndex();
          if (!_shouldKeepIndex(currentCenter, idx)) {
            _disposePreparedAt(idx);
          }
        });
      }
    }
  }

  void _preloadWindow(int center) {
    if (_videos.isEmpty) return;
    if (!_canPrecache) return; // disable on iOS
    final wanted = <String>{};

    // preload prev 1 and next 2
    if (center - 1 >= 0) wanted.add(_videos[center - 1].videoUrl);
    if (center + 1 < _videos.length) wanted.add(_videos[center + 1].videoUrl);
    if (center + 2 < _videos.length) wanted.add(_videos[center + 2].videoUrl);

    // start wanted
    for (var url in wanted) {
      _startPrecache(url);
    }

    // stop unwanted
    for (var url in _precaching.toList()) {
      if (!wanted.contains(url)) {
        _stopPrecache(url);
      }
    }
  }

  Future<void> _loadVideos({bool isLoadingShow = true, bool isRefresh = false}) async {
    if (_isFetchingMore) return;
    _isFetchingMore = true;
    if (isLoadingShow) setState(() => _isLoading = true);

    try {
      if (isRefresh) {
        _page = 1;
        _hasMore = true;
      }

      final videos = await ApiRepository.instance.videos.getVideosOnce(limit: _pageSize, page: _page,);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _videos = videos;
            _allVideos = videos;
          } else {
            _videos.addAll(videos);
            _allVideos.addAll(videos);
          }
          _isLoading = false;
          _hasMore = videos.length == _pageSize;
          _handlePreCachePreloading();
        });
      }
      _page++;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Graphics.showTopDialog(context, "Error!", 'Failed to load videos: $e', type: ToastType.error,);
      }
    } finally {
      _isFetchingMore = false;
    }
  }

  void _handlePreCachePreloading() {
    if (_videos.isNotEmpty) {
      final videosPerAd = SettingManager().nativeFrequency;
      final showAds = AppLovinAdManager.isMrecAdLoaded;
      final currentVideoIndex = showAds
          ? _currentIndex - (_currentIndex ~/ (videosPerAd + 1))
          : _currentIndex;
      final safeIndex = (currentVideoIndex >= 0 && currentVideoIndex < _videos.length)
          ? currentVideoIndex
          : 0;
      _preloadWindow(safeIndex);
      _clearPreparedControllers();
      _prepareControllersAround(safeIndex);
      _cleanupPreparedNotNeeded(safeIndex);
    }
  }

  Future<void> _refreshVideos() async {
    await _loadVideos(isLoadingShow: true, isRefresh: true);
  }

  void _openSearchScreen() {
    setScreenVisible(false);
    NavigationHelper.navigateWithAd(
      context: context,
      destination: const SearchScreen(),
    );
  }



  void _clearFilters() {
    _selectedTags.clear();
    setState(() {
      _videos = _allVideos;
      _currentIndex = 0;
    });
    _resetPageViewAndPrepare(0);
  }

  void _resetPageViewAndPrepare(int centerIndex) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    if (_videos.isNotEmpty) {
      _preloadWindow(centerIndex);
      _clearPreparedControllers();
      _prepareControllersAround(centerIndex);
      _cleanupPreparedNotNeeded(centerIndex);
    }
  }

  void _modifyVideo(String videoId, ApiVideo? Function(ApiVideo video) modifyFn) {
    bool changed = false;
    void updateList(List<ApiVideo> list) {
      final i = list.indexWhere((v) => v.id == videoId);
      if (i != -1) {
        final newVideo = modifyFn(list[i]);
        if (newVideo == null) {
          _disposePreparedAt(i);
          list.removeAt(i);

          if (_currentIndex >= list.length) {
            _currentIndex = list.isEmpty ? 0 : list.length - 1;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients && _videos.isNotEmpty) {
              _pageController.jumpToPage(_currentIndex);
              setState(() {});
            }
          });
        } else {
          list[i] = newVideo;
        }
        changed = true;
      }
    }

    updateList(_videos);
    updateList(_allVideos);

    if (changed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white),)
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

  Widget _buildFeedView() {
    int videosPerAd = SettingManager().nativeFrequency;
    final showAds = AppLovinAdManager.isMrecAdLoaded;
    final loadedVideos = _videos;
    final totalAds = showAds ? (loadedVideos.length / videosPerAd).floor() : 0;
    final totalItems = loadedVideos.length + totalAds;

    return RefreshIndicator(
      onRefresh: _refreshVideos,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: totalItems,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          final videoIndex = showAds ? index - (index ~/ (videosPerAd + 1)) : index;
          if (videoIndex >= 0 && videoIndex < _videos.length) {
            _preloadWindow(videoIndex);
            _prepareControllersAround(videoIndex);
            _cleanupPreparedNotNeeded(videoIndex);
          }

          if (_hasMore && !_isFetchingMore && videoIndex >= _videos.length - 3) {
            _loadVideos(isLoadingShow: false);
          }
        },
        itemBuilder: (context, index) {
          final isAdIndex = showAds && (index + 1) % (videosPerAd + 1) == 0;
          if (isAdIndex) {
            return SizedBox.expand(
              child: AppLovinAdManager.largeMrecAd(
                height: Utils(context).screenHeight,
                width: Utils(context).screenWidth,
              ),
            );
          }

          final videoIndex = showAds ? index - (index ~/ (videosPerAd + 1)) : index;
          if (videoIndex >= loadedVideos.length) return const SizedBox.shrink();
          final video = loadedVideos[videoIndex];

          final currentVideoIndex = showAds ? _currentIndex - (_currentIndex ~/ (videosPerAd + 1)) : _currentIndex;
          final shouldPreload = videoIndex >= currentVideoIndex - 1 && videoIndex <= currentVideoIndex + 2;
          final preparedController = _preparedControllers[videoIndex];
          final externalController = (preparedController?.isVideoInitialized() ?? false)
              ? preparedController
              : null;

          return VideoFeedItemWidget(
            key: ValueKey('${video.id}_$_isAuto'),
            video: video,
            isActive: index == _currentIndex && _isScreenVisible,
            shouldPreload: shouldPreload,
            isFromHome: true,
            isAuto: _isAuto,
            externalController: externalController,
            onVideoCompleted: () {
              if (_isAuto) {
                if (_pageController.hasClients) {
                  final nextPage = (_currentIndex + 1) % _videos.length;
                  _pageController.animateToPage(
                    nextPage,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
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
            onReported: (reportedVideo) {
              _modifyVideo(reportedVideo.id, (_) => null);
            },
            onFollowUpdated: (updatedUser) =>
                _modifyVideo(video.id, (v) => v.copyWith(user: updatedUser)),
            onPauseRequested: () => setScreenVisible(false),
            onResumeRequested: () => setScreenVisible(true),
          );
        },
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CircularIconButton(
          icon: Icons.search,
          onTap: _openSearchScreen,
          borderColor: Colors.white.withOpacity(0.3),
        ),
        FlutterSwitch(
          inactiveText: "Manual",
          activeText: "Auto",
          value: _isAuto,
          valueFontSize: 10.0,
          width: 80,
          height: 25,
          toggleSize: 20,
          borderRadius: 20.0,
          showOnOff: true,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.secondary,
          toggleColor: Theme.of(context).colorScheme.onPrimary,
          activeTextColor: Colors.black,
          inactiveTextColor: Colors.white,
          activeTextFontWeight: FontWeight.bold,
          inactiveTextFontWeight: FontWeight.bold,
          inactiveIcon: const Icon(Icons.touch_app, color: Colors.white, size: 16),
          activeIcon: const Icon(Icons.swap_vert, color: Colors.white, size: 16),
          onToggle: (val) {
            setState(() {
              _isAuto = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasTags = _selectedTags.isNotEmpty;
    return Center(
      child: EmptySection(
        icon: hasTags ? Icons.search_off : Icons.video_library_outlined,
        title: hasTags ? 'No videos found' : 'No videos yet',
        subtitle: hasTags
            ? 'Try different keywords or filters'
            : 'Be the first to share a video!',
        onRefresh: hasTags ? _clearFilters : _refreshVideos,
        refreshText: hasTags ? 'Clear Search' : 'Refresh',
      ),
    );
  }
}