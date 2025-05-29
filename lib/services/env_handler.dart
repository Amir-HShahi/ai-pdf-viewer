import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class EnvHandler {
  static void loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      throw Exception('Error loading .env file: $e');
    }
  }

  static String getBaseUrl() {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'default_url';
    return baseUrl;
  }

  static String getApiToken() {
    final String apiKey = dotenv.env['API_KEY'] ?? 'default_key';
    return apiKey;
  }
}
