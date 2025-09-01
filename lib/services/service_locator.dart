import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/error_handler.dart';
import '../services/socket_manager.dart';
import '../storage/chat_storage.dart';
import '../utils/connectivity_service.dart';
import '../services/http_client.dart';
import '../services/auth_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Service instances
  late ApiService _apiService;
  late ChatStorage _chatStorage;
  late ConnectivityService _connectivityService;
  late HttpClient _httpClient;
  late SocketManager _socketManager;
  

  // Getters
  ApiService get apiService => _apiService;
  ChatStorage get chatStorage => _chatStorage;
  ConnectivityService get connectivityService => _connectivityService;
  HttpClient get httpClient => _httpClient;
  SocketManager get socketManager => _socketManager;

  /// Initialize all services - singleton instance
  static ServiceLocator get instance => ServiceLocator();

  /// Initialize all services
  static Future<void> initialize() async {
    await instance._initialize();
  }

  Future<void> _initialize() async {
    debugPrint('ServiceLocator: Initializing services...');
    
    try {
      // Initialize connectivity service (lightweight)
      _connectivityService = ConnectivityService();
      _connectivityService.initialize().catchError((e) => debugPrint('ConnectivityService error: $e'));
      debugPrint('✓ ConnectivityService created');
      
      // Initialize chat storage (lightweight)
      _chatStorage = ChatStorage();
      debugPrint('✓ ChatStorage created');
      
      // Initialize HTTP client (lightweight)
      _httpClient = HttpClient();
      _httpClient.initialize().catchError((e) => debugPrint('HttpClient error: $e'));
      debugPrint('✓ HttpClient created');
      
      // Initialize API service (lightweight)
      _apiService = ApiService();
      _apiService.initialize().catchError((e) => debugPrint('ApiService error: $e'));
      debugPrint('✓ ApiService created');
      
      // // Initialize socket manager (lightweight)
      // _socketManager = SocketManager();
      // _socketManager.initialize(
      //   chatStorage: _chatStorage,
      //   connectivityService: _connectivityService,
      //   httpClient: _httpClient,
      // ).catchError((e) => debugPrint('SocketManager error: $e'));
      // debugPrint('✓ SocketManager created');
      
      // Initialize error handler
      ErrorHandler.initialize(navigatorKey: navigatorKey);
      debugPrint('✓ ErrorHandler initialized');
      
      debugPrint('ServiceLocator: All services created successfully!');
    } catch (e, stackTrace) {
      debugPrint('ServiceLocator: Failed to create services: $e');
      debugPrint('StackTrace: $stackTrace');
      // Don't rethrow - let app continue with limited functionality
    }
  }

  /// Update service dependencies after user authentication
  void updateAuthServices(AuthService authService) {
    ErrorHandler.initialize(
      authService: authService,
      navigatorKey: navigatorKey,
    );
    debugPrint('ServiceLocator: Auth services updated');
  }

  /// Connect to socket after authentication
  // Future<void> connectSocket({String? token}) async {
  //   try {
  //     await _socketManager.connect(token: token);
  //     debugPrint('ServiceLocator: Socket connected');
  //   } catch (e) {
  //     debugPrint('ServiceLocator: Failed to connect socket: $e');
  //     // Don't rethrow - socket connection is not critical for app startup
  //   }
  // }

  // /// Disconnect socket (usually on logout)
  // Future<void> disconnectSocket() async {
  //   try {
  //     await _socketManager.disconnect();
  //     debugPrint('ServiceLocator: Socket disconnected');
  //   } catch (e) {
  //     debugPrint('ServiceLocator: Error disconnecting socket: $e');
  //   }
  // }

  /// Clear all data (usually on logout)
  Future<void> clearAllData() async {
    try {
      await _chatStorage.clearAllData();
      _httpClient.clearTokens();
      // await disconnectSocket();
      debugPrint('ServiceLocator: All data cleared');
    } catch (e) {
      debugPrint('ServiceLocator: Error clearing data: $e');
    }
  }

  /// Dispose all services
  void dispose() {
    try {
      // _socketManager.dispose();
      _connectivityService.dispose();
      _chatStorage.dispose();
      debugPrint('ServiceLocator: All services disposed');
    } catch (e) {
      debugPrint('ServiceLocator: Error disposing services: $e');
    }
  }
}

/// Extension for easy access throughout the app
class Services {
  static ServiceLocator get locator => ServiceLocator();
  static ApiService get api => ServiceLocator().apiService;
  static ChatStorage get storage => ServiceLocator().chatStorage;
  static ConnectivityService get connectivity => ServiceLocator().connectivityService;
  static HttpClient get http => ServiceLocator().httpClient;
  static SocketManager get socket => ServiceLocator().socketManager;
  static GlobalKey<NavigatorState> get navigatorKey => navigatorKey;
}

/// Usage examples and helper methods
class ApiHelper {
  /// Safe API call with loading state
  static Future<T?> safeCall<T>(
    Future<T?> Function() apiCall, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
    Function(String)? onError,
  }) async {
    try {
      onLoadingStart?.call();
      final result = await apiCall();
      return result;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    } finally {
      onLoadingEnd?.call();
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await Services.storage.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user ID
  static Future<String?> getCurrentUserId() async {
    final userId = await Services.storage.getCurrentUserId();
    return userId.isNotEmpty ? userId : null;
  }
}

/// Update your main function with service initialization
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   try {
///     await ServiceLocator().initialize();
///   } catch (e) {
///     debugPrint('Failed to initialize services: $e');
///   }
///   
///   runApp(MyApp());
/// }
/// 
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       navigatorKey: Services.navigatorKey, // Important for error handling
///       // ... rest of your app
///     );
///   }
/// }
/// ```