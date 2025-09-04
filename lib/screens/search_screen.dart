import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/services/search_service.dart';
import 'package:vidstream/screens/video_player_screen.dart';
import 'package:vidstream/screens/other_user_profile_screen.dart';
import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../utils/utils.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/professional_bottom_ad.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

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
    if (query.trim().isEmpty) {
      _loadDefaultContent(true);
      setState(() {
        _hasSearched = false;
        _currentQuery = '';
      });
      return;
    }

    _searchService.cancelSearch();

    setState(() {
      if(isLoading) {
        _isLoading = true;
      }
      _hasSearched = true;
      _currentQuery = query.trim();
    });

    try {
      final videos = await _searchService.searchVideos(query.trim());
      final users = await _searchService.searchUsers(query.trim());

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
    const int rowsBeforeAd = 2;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> children = [];

    for (int i = 0; i < _videos.length; i += videosPerChunk) {
      final end = (i + videosPerChunk < _videos.length) ? i + videosPerChunk : _videos.length;
      final videosChunk = _videos.sublist(i, end);

      // Add Grid for this chunk
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
            return _buildVideoGridItem(video, double.infinity, double.infinity);
          },
        ),
      );

      children.add(const SizedBox(height: 8));
      if (AppLovinAdManager.isNativeAdLoaded) {
        children.add(AppLovinAdManager.nativeAdSmall(height: 110));
        children.add(const SizedBox(height: 8));
      }
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
            child: ListView(
              children: children,
            ),
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

    final adInterval = 4;
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
                if (AppLovinAdManager.isNativeAdLoaded) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: AppLovinAdManager.nativeAdSmall(height: 90),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasSearched ? Icons.person_search : Icons.star,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _hasSearched
                ? 'No users found for "$_currentQuery"'
                : 'No popular users available',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_hasSearched) ...[
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyVideosState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasSearched ? Icons.search_off : Icons.trending_up,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _hasSearched
                ? 'No videos found for "$_currentQuery"'
                : 'No trending videos available',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_hasSearched) ...[
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoGridItem(ApiVideo video, double width, double height) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          NavigationHelper.navigateWithAd<String?>(
            context: context,
            destination: VideoPlayerScreen(
              video: video,
              allVideos: _videos,
              user: null,
            ),
            onReturn: (result) {
              if (result != null) {
                if (_currentQuery.isNotEmpty) {
                  _performSearch(_currentQuery, isLoading: false);
                } else {
                  _loadDefaultContent(false);
                }
              }
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CustomImageWidget(
                imageUrl: video.thumbnailUrl,
                height: height,
                width: width,
                cornerRadius: 12,
              ),

              // Play button
              Center(
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
              ),

              // Video stats
              Positioned(
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
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatCount(video.likesCount),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatCount(video.viewsCount),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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