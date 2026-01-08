import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local data source for caching authentication state.
/// Enables offline access by persisting user data locally.
@lazySingleton
class AuthLocalDataSource {
  AuthLocalDataSource({required SharedPreferences sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  static const String _authCacheKey = 'cached_auth_user';
  static const String _authStateKey = 'is_authenticated';

  /// Caches the authenticated user data locally.
  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    // Create a copy and convert non-JSON-serializable types
    final serializableData = Map<String, dynamic>.from(userData);

    // Convert Timestamp or DateTime to ISO string for JSON serialization
    final createdAt = serializableData['createdAt'];
    if (createdAt != null) {
      if (createdAt is DateTime) {
        serializableData['createdAt'] = createdAt.toIso8601String();
      } else {
        // Handle Firestore Timestamp - it has a toDate() method
        try {
          serializableData['createdAt'] = (createdAt as dynamic).toDate().toIso8601String();
        } catch (_) {
          serializableData['createdAt'] = DateTime.now().toIso8601String();
        }
      }
    }

    await _sharedPreferences.setString(
      _authCacheKey,
      json.encode(serializableData),
    );
    await _sharedPreferences.setBool(_authStateKey, true);
  }

  /// Retrieves cached user data.
  /// Returns null if no cached data exists.
  Map<String, dynamic>? getCachedUserData() {
    final cachedData = _sharedPreferences.getString(_authCacheKey);
    if (cachedData == null) return null;

    try {
      return json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      // If decoding fails, return null
      return null;
    }
  }

  /// Checks if a user is authenticated (has valid cached data).
  bool isAuthenticated() {
    return _sharedPreferences.getBool(_authStateKey) ?? false;
  }

  /// Clears cached authentication data.
  /// Should be called on sign out or account deletion.
  Future<void> clearAuthCache() async {
    await _sharedPreferences.remove(_authCacheKey);
    await _sharedPreferences.setBool(_authStateKey, false);
  }
}
