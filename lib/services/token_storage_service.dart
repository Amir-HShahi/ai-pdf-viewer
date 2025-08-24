import 'package:shared_preferences/shared_preferences.dart';

class TokenStorageService {
  static const String _apiTokenKey = 'api_token';
  static const String _baseUrlKey = 'base_url';

  // Get stored API token
  Future<String?> getApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiTokenKey);
  }

  // Save API token
  Future<void> saveApiToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiTokenKey, token);
  }

  // Remove API token
  Future<void> removeApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiTokenKey);
  }

  // Get stored base URL (optional - if you want to make this configurable too)
  Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey);
  }

  // Save base URL (optional)
  Future<void> saveBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
  }

  // Check if API token exists
  Future<bool> hasApiToken() async {
    final token = await getApiToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all stored data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiTokenKey);
    await prefs.remove(_baseUrlKey);
  }
}