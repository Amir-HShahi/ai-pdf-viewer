import 'dart:convert';

import 'package:ai_pdf_viewer/services/env_handler.dart';
import 'package:ai_pdf_viewer/services/token_storage_service.dart';
import 'package:http/http.dart' as http;

abstract class Summarizer {
  static Future<String> getSummary(String text) async {
    try {
      if (text.isEmpty) {
        return 'Error: Text is not provided';
      }

      // Get API token from storage first, fallback to environment
      final tokenStorage = TokenStorageService();
      String? apiToken = await tokenStorage.getApiToken();

      if (apiToken == null || apiToken.isEmpty) {
        apiToken = EnvHandler.getApiToken();
        if (apiToken.isEmpty) {
          return 'Error: API token not configured. Please set your API token in settings.';
        }
      }

      final response = await http.post(
        Uri.parse('${EnvHandler.getBaseUrl()}/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'token': apiToken,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['ok'] == true && data['message'] == "Text is not provided") {
          return 'Error: Text is not provided';
        }

        if (data.containsKey('data')) {
          return data['data'] ?? 'No summary available';
        }

        return data['summary'] ?? 'No summary available';
      } else if (response.statusCode == 401) {
        return 'Error: Invalid API token. Please check your token in settings.';
      } else if (response.statusCode == 403) {
        return 'Error: API token expired or insufficient permissions.';
      } else {
        return 'Error: Unable to generate summary (HTTP ${response.statusCode})';
      }
    } catch (e) {
      return 'Error: Network issue or server unavailable - $e';
    }
  }
}