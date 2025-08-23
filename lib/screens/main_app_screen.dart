import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vidstream/screens/home_screen.dart';
import 'package:vidstream/screens/profile_screen.dart';
import 'package:vidstream/screens/create_post_screen.dart';
import 'package:vidstream/screens/meet_screen.dart';
import 'package:vidstream/screens/chat_list_screen.dart';

import '../manager/firebase_manager.dart';
import '../services/meet_service.dart';

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
    // FirebaseManager().initNotification();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      const MeetScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CreatePostScreen(),
          fullscreenDialog: true,
        ),
      );
    } else {
      final newIndex = index > 2 ? index - 1 : index;
      
      // Notify HomeScreen about visibility change
      if (_currentIndex == 0 && newIndex != 0) {
        // Moving away from Home screen
        _homeScreenKey.currentState?.setScreenVisible(false);
      } else if (_currentIndex != 0 && newIndex == 0) {
        // Moving to Home screen
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

      print('Latitude: $latitude, Longitude: $longitude, City: $city, Country: $country');

      await _meetService.updateLocation(
        latitude: latitude,
        longitude: longitude,
        city: city,
        country: country,
      );
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isActive: _currentIndex == 0,
                ),
                
                // Meet
                _buildNavItem(
                  icon: Icons.videocam_outlined,
                  activeIcon: Icons.videocam,
                  label: 'Meet',
                  index: 1,
                  isActive: _currentIndex == 1,
                ),
                
                // Create Post (Center Button)
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                
                // Chat
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Chat',
                  index: 3,
                  isActive: _currentIndex == 2,
                ),
                
                // Profile
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
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}