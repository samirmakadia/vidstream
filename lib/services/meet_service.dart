import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/repositories/api_repository.dart';

class MeetService {
  final ApiRepository _apiRepository = ApiRepository.instance;

  Future<void> joinMeet() async {
    final currentUser = _apiRepository.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    try {
      await _apiRepository.api.joinMeet();
    } catch (e) {
      throw Exception('Failed to join meet: $e');
    }
  }

  // Leave the meet
  Future<void> leaveMeet() async {
    final currentUser = _apiRepository.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      await _apiRepository.api.leaveMeet();
    } catch (e) {
      throw Exception('Failed to leave meet: $e');
    }
  }

  // Get online users for meet
  Stream<List<ApiUser>> getOnlineUsers({
    String? genderFilter,
    double? maxDistanceKm,
  }) async* {
    try {
      while (true) {
        final onlineUsers = await _apiRepository.api.getOnlineUsers();
        yield onlineUsers;
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      print('Error getting online users: $e');
      yield [];
    }
  }

  Stream<List<ApiUser>> getNearbyUsersStream({
    required String genderFilter,
    int? minAge,
    int? maxAge,
    int? maxDistance,
    Duration refreshInterval = const Duration(seconds: 5),
  }) async* {
    try {
      while (true) {
        final response = await _apiRepository.api.getNearbyUsers(
          genderFilter: genderFilter,
          minAge: minAge,
          maxAge: maxAge,
          maxDistance: maxDistance,
        );

        print('NearbyUsersResponse users: ${response?.users}');
        print('NearbyUsersResponse totalCount: ${response?.totalCount}');
        print('NearbyUsersResponse filters: ${response?.filters.maxDistance}');

        yield response?.users ?? [];
        await Future.delayed(refreshInterval);
      }
    } catch (e, st) {
      print('Error getting nearby users: $e\n$st');
      yield [];
    }
  }

  // Check if user is in meet
  Future<bool> isUserInMeet() async {
    try {
      final isOnline = await _apiRepository.api.getOnlineUserStatus();
      return isOnline;
    } catch (e) {
      print('Error checking meet status: $e');
      return false;
    }
  }

  // Get current location
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }

  // Filter users by distance
  List<OnlineUser> filterUsersByDistance(
    List<OnlineUser> users,
    Position currentPosition,
    double maxDistanceKm,
  ) {
    return users.where((user) {
      if (user.latitude == null || user.longitude == null) return false;
      
      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        user.latitude!,
        user.longitude!,
      );
      
      return distance <= maxDistanceKm;
    }).toList();
  }

  // Update user location
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? city,
    String? country,
  }) async {
    try {
      await _apiRepository.api.updateUserLocation(
        latitude: latitude,
        longitude: longitude,
        city: city,
        country: country,
      );
    } catch (e) {
      print('Error updating location: $e');
    }
  }
}