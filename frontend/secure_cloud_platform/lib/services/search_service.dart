import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drive_model.dart';
import 'auth_service.dart';

class SearchService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<List<FileItem>> searchFiles(String query) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['files'] as List).map((file) => FileItem.fromJson(file)).toList();
    } else {
      throw Exception('Search failed');
    }
  }

  static Future<List<FileItem>> getRecentFiles({int limit = 20}) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/recent-files?limit=$limit'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['files'] as List).map((file) => FileItem.fromJson(file)).toList();
    } else {
      throw Exception('Failed to get recent files');
    }
  }

  static Future<List<FileItem>> getFavoriteFiles() async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/favorites'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['files'] as List).map((file) => FileItem.fromJson(file)).toList();
    } else {
      throw Exception('Failed to get favorites');
    }
  }

  static Future<void> toggleFavorite(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/toggle-favorite'),
      headers: headers,
      body: jsonEncode({
        'drive_id': driveId,
        'file_id': fileId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle favorite');
    }
  }

  static Future<List<String>> getSuggestedTags(String fileName) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/suggest-tags'),
      headers: headers,
      body: jsonEncode({'file_name': fileName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tags'] as List).cast<String>();
    } else {
      return [];
    }
  }
}