import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class Summarizer {
  static Future<String> getSummary(String text) async {
    try {
      if (text.isEmpty) {
        return 'Error: Text is not provided';
      }

      final response = await http.post(
        Uri.parse('https://ai-pdf-summarizer-api.vercel.app/ai/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'token':
              '',
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
      } else {
        return 'Error: Unable to generate summary';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
