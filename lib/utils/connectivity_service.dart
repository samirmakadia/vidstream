import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamController<bool> _connectivityController;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Stream<bool> get connectivityStream => _connectivityController.stream;

  Future<void> initialize() async {
    _connectivityController = StreamController<bool>.broadcast();
    
    // Check initial connectivity
    await _updateConnectivityStatus();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('Connectivity stream error: $error');
      },
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _updateConnectivityStatus();
  }

  Future<void> _updateConnectivityStatus() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      final bool wasConnected = _isConnected;
      
      _isConnected = results.any((result) => 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet
      );
      
      if (wasConnected != _isConnected) {
        debugPrint('Connectivity changed: $_isConnected');
        _connectivityController.add(_isConnected);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      // Assume connected on error to not block functionality
      if (!_isConnected) {
        _isConnected = true;
        _connectivityController.add(_isConnected);
      }
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _connectivityController.close();
  }
}