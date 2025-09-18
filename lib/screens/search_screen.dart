import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:vidmeet/manager/setting_manager.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/services/search_service.dart';
import 'package:vidmeet/screens/video_player_screen.dart';
import 'package:vidmeet/screens/other_user_profile_screen.dart';
import '../helper/navigation_helper.dart';
import '../manager/applovin_ad_manager.dart';
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
  final ScrollController _videosController = ScrollController();
  final ScrollController _usersController = ScrollController();
  late TabController _tabController;
  CancelToken? _cancelToken;

  List<ApiVideo> _videos = [];
  List<ApiUser> _users = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentQuery = '';
  bool _isSearching = false;
  Timer? _debounce;

  bool _isFetchingVideosPagination = false;
  bool _isFetchingUsersPagination = false;

  int _videosPage = 1;
  int _usersPage = 1;
  final int _pageSize = 20;

  bool _hasMoreVideos = true;
  bool _hasMoreUsers = true;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_isSearching) setState(() {});
    });

    _loadDefaultContent(true);

    _videosController.addListener(() {
      if (_videosController.position.pixels >=
          _videosController.position.maxScrollExtent - 200 &&
          !_isFetchingVideosPagination &&
          _hasMoreVideos) {
        _fetchVideos(isLoading: false);
      }
    });

    _usersController.addListener(() {
      if (_usersController.position.pixels >=
          _usersController.position.maxScrollExtent - 200 &&
          !_isFetchingUsersPagination &&
          _hasMoreUsers) {
        _fetchUsers(isLoading: false);
      }
    });
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

  Future<void> _fetchVideos({bool isLoading = true, bool reset = false}) async {
    if (isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    if (!_hasMoreVideos || _isFetchingVideosPagination) return;

    if (!reset) {
      setState(() => _isFetchingVideosPagination = true);
    }

    try {
      if (reset) {
        _videosPage = 1;
        _hasMoreVideos = true;
      }

      final newVideos = _currentQuery.isNotEmpty
          ? await _searchService.searchVideos(
          _currentQuery, _cancelToken,
          page: _videosPage, limit: _pageSize)
          : await _searchService.getTrendingVideos(
          limit: _pageSize, page: _videosPage);

      if (!mounted) return;

      setState(() {
        if (_videosPage == 1) {
          _videos = newVideos;
        } else {
          _videos.addAll(newVideos);
        }
        _hasMoreVideos = newVideos.length == _pageSize;
        if (_hasMoreVideos) {
          _videosPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching videos pagination: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isFetchingVideosPagination = false;
      });
    }
  }

  Future<void> _fetchUsers({bool isLoading = true, bool reset = false}) async {
    if (isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    if (!_hasMoreUsers || _isFetchingUsersPagination) return;

    if(!reset) {
      setState(() => _isFetchingUsersPagination = true);
    }

    try {
      if (reset) {
        _usersPage = 1;
        _hasMoreUsers = true;
      }
      final newUsers = _currentQuery.isNotEmpty
          ? await _searchService.searchUsers(_currentQuery, _cancelToken, page: _usersPage, limit: _pageSize)
          : await _searchService.getPopularUsers(limit: _pageSize, page: _usersPage);

      if (!mounted) return;

      setState(() {
        if (_usersPage == 1) {
          _users = newUsers;
        } else {
          _users.addAll(newUsers);
        }
        _hasMoreUsers = newUsers.length == _pageSize;
        if (_hasMoreUsers) {
          _usersPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching users pagination: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isFetchingUsersPagination = false;
      });
    }
  }

  void _loadDefaultContent(bool isLoading) async {
    await _fetchVideos(isLoading: isLoading, reset: true);
    await _fetchUsers(isLoading: isLoading, reset: true);
  }

  void _performSearch(String query, {bool isLoading = true}) async {
    _cancelToken?.cancel('Cancelled previous request');
    _cancelToken = CancelToken();

    final trimmedQuery = query.trim();

    setState(() {
      _isLoading = isLoading;
      _videos.clear();
      _users.clear();
      _hasSearched = true;
      _currentQuery = trimmedQuery;
      _videosPage = 1;
      _usersPage = 1;
      _hasMoreVideos = true;
      _hasMoreUsers = true;
    });

    if (trimmedQuery.isEmpty) {
      setState(() => _hasSearched = false);
      _loadDefaultContent(true);
      return;
    }

    try {
      final videos = await _searchService.searchVideos(
        trimmedQuery,
        _cancelToken,
        page: _videosPage,
        limit: _pageSize,
      );

      final users = await _searchService.searchUsers(
        trimmedQuery,
        _cancelToken,
        page: _usersPage,
        limit: _pageSize,
      );

      setState(() {
        _videos = videos;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() => _isLoading = false);
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          _hasSearched = false;
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
    if (_isLoading && _videos.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_videos.isEmpty) {
      return _buildEmptyVideosState();
    }

    const int videosPerRow = 3;
    int rowsBeforeAd = SettingManager().nativeFrequency;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> items = [];

    for (int i = 0; i < _videos.length; i += videosPerChunk) {
      final end = (i + videosPerChunk < _videos.length) ? i + videosPerChunk : _videos.length;
      final chunk = _videos.sublist(i, end);

      items.add(GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.only(top: 10,bottom: 20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: chunk.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: videosPerRow,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (context, index) {
          final video = chunk[index];
          return VideoGridItemWidget(
            key: ValueKey(video.id),
            video: video,
            onTap: () => _openVideoPlayer(video),
          );
        },
      ));

      if (AppLovinAdManager.isMrecAdLoaded && end < _videos.length) {
        items.add(const SizedBox(height: 8));
        items.add(AppLovinAdManager.mrecAd());
        items.add(const SizedBox(height: 8));
      }
    }

    if (AppLovinAdManager.isMrecAdLoaded &&
        (_videos.length < videosPerChunk || _videos.length % videosPerChunk != 0)) {
      items.add(const SizedBox(height: 8));
      items.add(AppLovinAdManager.mrecAd());
      items.add(const SizedBox(height: 8));
    }

    if (_isFetchingVideosPagination) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ));
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
          child: ListView(
            controller: _videosController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _users.isEmpty) {
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
            controller: _usersController,
            itemCount: totalItems + (_isFetchingUsersPagination ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isFetchingUsersPagination && index == totalItems) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

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
                        _performSearch(_currentQuery);
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
    final snapshot = List<ApiVideo>.from(_videos);
    final startIndex = snapshot.indexWhere((v) => v.id == video.id);

    AppLovinAdManager.handleScreenOpen(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              video: video,
              allVideos: snapshot,
              initialIndex: startIndex >= 0 ? startIndex : 0,
              user: null,
            ),
          ),
        );

        // Refresh content after returning
        if (_currentQuery.isNotEmpty) {
          _performSearch(_currentQuery);
        } else {
          _loadDefaultContent(false);
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