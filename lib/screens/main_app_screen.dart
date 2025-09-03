import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidstream/screens/home_screen.dart';
import 'package:vidstream/screens/profile_screen.dart';
import 'package:vidstream/screens/create_post_screen.dart';
import 'package:vidstream/screens/meet_screen.dart';
import 'package:vidstream/screens/chat_list_screen.dart';

import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../manager/firebase_manager.dart';
import '../manager/session_manager.dart';
import '../services/meet_service.dart';
import '../services/notification_service.dart';
import '../services/socket_manager.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final MeetService _meetService = MeetService();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _updateUserLocation();
    NotificationService().initialize();
    _connectSocket();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      const MeetScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _connectSocket() async {
    final token = await SessionManager().getAccessToken();
    print("Retrieved token: $token");
    if (token != null && token.isNotEmpty) {
      await SocketManager().connect(token: token);
    }
  }

  Future<void> _requestPermissions() async {
    LocationPermission locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (await Permission.notification.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      _homeScreenKey.currentState?.setScreenVisible(false);
      NavigationHelper.navigateWithAd(
        context: context,
        destination: const CreatePostScreen(),
        onReturn: (_) {
          _homeScreenKey.currentState?.setScreenVisible(true);
        },
      );
    } else {
      final newIndex = index > 2 ? index - 1 : index;
      if (_currentIndex == 0 && newIndex != 0) {
        _homeScreenKey.currentState?.setScreenVisible(false);
      } else if (_currentIndex != 0 && newIndex == 0) {
        _homeScreenKey.currentState?.setScreenVisible(true);
      }
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  Future<void> _updateUserLocation() async {
    try {
      Position? position;
      position = await _meetService.getCurrentLocation();
      double latitude = position.latitude;
      double longitude = position.longitude;
      String city = "Unknown";
      String country = "Unknown";

      List<Placemark> placemarks =
      await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        city = place.locality ?? "Unknown";
        country = place.country ?? "Unknown";
      }
      await _meetService.updateLocation(latitude: latitude, longitude: longitude, city: city, country: country,);
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }


  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                isActive: _currentIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.videocam_outlined,
                activeIcon: Icons.videocam,
                label: 'Meet',
                index: 1,
                isActive: _currentIndex == 1,
              ),
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _onTabTapped(2),
                    child: const Icon(
                      Icons.add,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chat',
                iconSize: 22,
                index: 3,
                isActive: _currentIndex == 2,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
                isActive: _currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    int? iconSize = 25,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive 
                    ? Theme.of(context).colorScheme.primary
                    : Color(0xFFE0E0E0).withValues(alpha: 0.6),
                size: iconSize?.toDouble(),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive 
                    ? Theme.of(context).colorScheme.primary
                    : Color(0xFFE0E0E0).withValues(alpha: 0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}