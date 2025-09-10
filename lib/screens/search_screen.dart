import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:vidmeet/manager/setting_manager.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/services/search_service.dart';
import 'package:vidmeet/screens/video_player_screen.dart';
import 'package:vidmeet/screens/other_user_profile_screen.dart';
import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../utils/utils.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/empty_section.dart';
import '../widgets/professional_bottom_ad.dart';
import '../widgets/video_grid_item_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  CancelToken? _cancelToken;

  List<ApiVideo> _videos = [];
  List<ApiUser> _users = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentQuery = '';
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    print('Search screen initialized ${SettingManager().fullscreenFrequency}');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_isSearching) {
        setState(() {});
      }
    });
    _loadDefaultContent(true);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadDefaultContent(bool isLoading) async {
    if(isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final trendingVideos = await _searchService.getTrendingVideos(limit: 20);
      final popularUsers = await _searchService.getPopularUsers(limit: 20);

      setState(() {
        _videos = trendingVideos;
        _users = popularUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading default content: $e');
    }
  }

  void _performSearch(String query, {bool isLoading = true}) async {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Cancelled previous request');
    }

    _cancelToken = CancelToken();
    if (query.trim().isEmpty) {
      setState(() {
        _isLoading = true;
        _videos.clear();
        _users.clear();
        _hasSearched = false;
        _currentQuery = '';
      });
      _loadDefaultContent(true);
      return;
    }

    setState(() {
      if(isLoading) {
        _isLoading = true;
      }
      _hasSearched = true;
      _currentQuery = query.trim();
    });

    try {
      final videos = await _searchService.searchVideos(query.trim(),_cancelToken);
      final users = await _searchService.searchUsers(query.trim(),_cancelToken);
      setState(() {
        _videos = videos;
        _users = users;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error performing search: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: _isSearching ? _buildSearchField(context) : const Text('Search'),
        leading: _isSearching ? _buildBackButton() : null,
        bottom: !_isSearching ? _buildSearchTabBar(context) : null,
      ),
      body: SafeArea(
        child: ProfessionalBottomAd(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVideosTab(),
              _buildUsersTab(),
            ],
          ),
        ),
      ),
    );
  }

  String _getSearchHint() {
    if (_tabController.index == 0) {
      return 'Search videos';
    } else {
      return 'Search users';
    }
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: _getSearchHint(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              _performSearch('');
              setState(() {});
            },
          )
              : null,
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
        _performSearch('');
      },
    );
  }

  PreferredSize _buildSearchTabBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => setState(() => _isSearching = true),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Search videos, users...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            dividerColor: Colors.grey.withOpacity(0.5),
            tabs: [
              _buildTab(Icons.play_arrow, 'Videos'),
              _buildTab(Icons.people, 'Users'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_videos.isEmpty) return _buildEmptyVideosState();

    const int videosPerRow = 3;
    const int rowsBeforeAd = 3;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> children = [];

    for (int i = 0; i < _videos.length; i += videosPerChunk) {
      final end = (i + videosPerChunk < _videos.length)
          ? i + videosPerChunk
          : _videos.length;
      final videosChunk = _videos.sublist(i, end);

      children.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videosChunk.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: videosPerRow,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.7,
          ),
          itemBuilder: (context, index) {
            final video = videosChunk[index];
            return VideoGridItemWidget(
              video: video,
              onTap: () => _openVideoPlayer(video),
            );
          },
        ),
      );

      if (AppLovinAdManager.isMrecAdLoaded && end < _videos.length) {
        children.add(const SizedBox(height: 8));
        children.add(AppLovinAdManager.mrecAd());
        children.add(const SizedBox(height: 8));
      }
    }

    if (AppLovinAdManager.isMrecAdLoaded && (_videos.length < videosPerChunk ||
        _videos.length % videosPerChunk != 0)) {
      children.add(const SizedBox(height: 8));
      children.add(AppLovinAdManager.mrecAd());
      children.add(const SizedBox(height: 8));
    }

    return Column(
      children: [
        if (!_hasSearched)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              '🔥 Trending Videos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return _buildEmptyUsersState();
    }

    int adInterval = SettingManager().nativeFrequency;
    final totalItems = Utils.getTotalItems(_users.length, adInterval);

    return Column(
      children: [
        if (!_hasSearched)
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              '⭐ Popular Users',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: totalItems,
            itemBuilder: (context, index) {
              if (Utils.isAdIndex(index, _users.length, adInterval, totalItems)) {
                if (AppLovinAdManager.isMrecAdLoaded) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: AppLovinAdManager.mrecAd(),
                  );
                } else {
                  // Skip ad, don't reserve space
                  return const SizedBox.shrink();
                }
              }

              final userIndex = Utils.getUserIndex(index, _users.length, adInterval);
              final user = _users[userIndex];

              return UserCard(
                user: user,
                onTap: () {
                  NavigationHelper.navigateWithAd(
                    context: context,
                    destination: OtherUserProfileScreen(userId: user.id),
                    onReturn: (_) {
                      if (_currentQuery.isNotEmpty) {
                        _performSearch(_currentQuery, isLoading: false);
                      } else {
                        _loadDefaultContent(false);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyUsersState() {
    return Center(
      child: EmptySection(
        icon: _hasSearched ? Icons.person_search : Icons.star,
        title: _hasSearched
            ? 'No users found for "$_currentQuery"'
            : 'No popular users available',
        subtitle: _hasSearched
            ? 'Try different keywords or check your spelling'
            : '',
      ),
    );
  }


  Widget _buildEmptyVideosState() {
    return Center(
      child: EmptySection(
        icon: _hasSearched ? Icons.search_off : Icons.trending_up,
        title: _hasSearched
            ? 'No videos found for "$_currentQuery"'
            : 'No trending videos available',
        subtitle: _hasSearched
            ? 'Try different keywords or check your spelling'
            : '',
      ),
    );
  }

  Future<void> _openVideoPlayer(ApiVideo video) async {
    AppLovinAdManager.handleScreenOpen(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final  result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) =>  VideoPlayerScreen(
            video: video,
            allVideos: _videos,
            user: null,
          )),
        );
        if (result != null) {
          if (_currentQuery.isNotEmpty) {
            _performSearch(_currentQuery, isLoading: false);
          } else {
            _loadDefaultContent(false);
          }
        }
      });
    });
  }
}


class UserCard extends StatelessWidget {
  final ApiUser user;
  final VoidCallback onTap;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    print('Building UserCard for user: ${user.profileImageUrl}');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CustomImageWidget(
                imageUrl: user.profileImageUrl ?? '',
                height: 42,
                width: 42,
                cornerRadius: 25,
                isUserInitial: true,
                initials: Utils.getInitials(user.displayName),
                initialsBgColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                initialsTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (user.bio?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Stats
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user.followersCount} followers',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),

                        const SizedBox(width: 16),

                        Icon(
                          Icons.video_library,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user.videosCount} videos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}