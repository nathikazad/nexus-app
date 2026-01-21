import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User model containing authentication information
class User {
  final String userId;
  final String endpoint;

  User({required this.userId, required this.endpoint});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          endpoint == other.endpoint;

  @override
  int get hashCode => userId.hashCode ^ endpoint.hashCode;
}

/// AuthController manages user authentication state.
/// Loads saved credentials from SharedPreferences on initialization.
class AuthController extends AsyncNotifier<User?> {
  static const String _userIdKey = 'auth_user_id';
  static const String _endpointKey = 'auth_endpoint';

  @override
  Future<User?> build() async {
    await Future.delayed(const Duration(seconds: 1));
    print('[AuthController] build() - Initializing auth state');
    
    // Load saved credentials from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      final endpoint = prefs.getString(_endpointKey);
      
      if (userId != null && endpoint != null && userId.isNotEmpty && endpoint.isNotEmpty) {
        print('[AuthController] Found saved credentials: userId=$userId, endpoint=$endpoint');
        return User(userId: userId, endpoint: endpoint);
      } else {
        print('[AuthController] No saved credentials found');
        return null;
      }
    } catch (e) {
      print('[AuthController] Error loading saved credentials: $e');
      return null;
    }
  }

  /// Logs in a user with the given userId and endpoint.
  /// Saves credentials to SharedPreferences and updates state.
  /// Returns null if login was successful, error message String otherwise.
  Future<String?> login(String userId, String endpoint) async {
    //delay for 2 seconds
    print('[AuthController] login() - Logging in user: $userId, endpoint: $endpoint');
    state = const AsyncValue.loading();
    
    try {
      // Validate inputs
      if (userId.isEmpty || endpoint.isEmpty) {
        throw Exception('User ID and endpoint are required');
      }
      
      // Validate endpoint URL
      if (!endpoint.startsWith('http://') && !endpoint.startsWith('https://')) {
        throw Exception('Endpoint must start with http:// or https://');
      }
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_endpointKey, endpoint);
      
      // Update state
      final user = User(userId: userId, endpoint: endpoint);
      state = AsyncValue.data(user);
      print('[AuthController] Login successful');
      return null; // null means success
    } catch (e, stackTrace) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('[AuthController] Login error: $errorMessage');
      state = AsyncValue.error(e, stackTrace);
      return errorMessage; // Return error message
    }
  }

  /// Logs out the current user.
  /// Clears SharedPreferences and updates state to null.
  Future<void> logout() async {
    
    print('[AuthController] logout() - Logging out user');
    state = const AsyncValue.loading();
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_endpointKey);
      
      // Update state
      state = const AsyncValue.data(null);
      //delay for 2 seconds
      
      print('[AuthController] Logout successful');
    } catch (e, stackTrace) {
      print('[AuthController] Logout error: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
}



/// Provider for the AuthController.
final authProvider = AsyncNotifierProvider<AuthController, User?>((() {
  return AuthController();
}), name: 'authProvider');

/// Provider that returns the current user's ID, or null if not logged in.
/// Derived from authProvider.
final userIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.value?.userId;
}, name: 'userIdProvider');

/// Provider that returns the current endpoint, or null if not logged in.
/// Derived from authProvider.
final endpointProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.value?.endpoint;
}, name: 'endpointProvider');

/// AppStatus enum representing the three possible states of the app.
enum AppStatus {
  /// App is still initializing (loading auth state)
  initializing,
  
  /// User is authenticated
  authenticated,
  
  /// User is not authenticated
  unauthenticated,
}

/// Provider that returns the current AppStatus based on the auth state.
/// Provides a stable status that prevents router flicker.
final appStatusProvider = Provider<AppStatus>((ref) {
  final authState = ref.watch(authProvider);
  
  return authState.when(
    data: (user) => user == null ? AppStatus.unauthenticated : AppStatus.authenticated,
    loading: () => AppStatus.initializing,
    error: (_, __) => AppStatus.unauthenticated,
  );
}, name: 'appStatusProvider');


