import 'package:geolocator/geolocator.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';

class MeetService {
  final ApiRepository _apiRepository = ApiRepository.instance;

  // Join the meet - mark user as online and in meet
  Future<void> joinMeet() async {
    final currentUser = _apiRepository.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        print('Failed to get location: $e');
      }

      // Update user location if available
      if (position != null) {
        await _apiRepository.api.updateUserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
      
      // Join meet using placeholder meet ID (implement meet ID logic as needed)
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
        await Future.delayed(const Duration(seconds: 5)); // Refresh every 5 seconds
      }
    } catch (e) {
      print('Error getting online users: $e');
      yield [];
    }
  }

  // Check if user is in meet
  Future<bool> isUserInMeet(String userId) async {
    try {
      final isOnline = await _apiRepository.api.getOnlineUserStatus(userId);
      return isOnline;
    } catch (e) {
      print('Error checking meet status: $e');
      return false;
    }
  }

  // Get current location
  Future<Position> _getCurrentLocation() async {
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
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await _apiRepository.api.updateUserLocation(latitude: latitude, longitude: longitude);
    } catch (e) {
      print('Error updating location: $e');
    }
  }
}