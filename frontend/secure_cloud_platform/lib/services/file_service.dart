import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drive_model.dart';
import 'auth_service.dart';

class FileService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<List<Drive>> getUserDrives() async {
    final headers = await AuthService.getAuthHeaders();
    
    // Get user drives from Supabase via API
    final response = await http.get(
      Uri.parse('$baseUrl/user/drives'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Drive> drives = [
        Drive(id: 'shared', name: 'Shared Drive (15GB)', type: 'shared', createdAt: DateTime.now())
      ];
      
      for (var driveData in data['drives'] ?? []) {
        drives.add(Drive.fromJson(driveData));
      }
      
      return drives;
    } else {
      return [Drive(id: 'shared', name: 'Shared Drive (15GB)', type: 'shared', createdAt: DateTime.now())];
    }
  }

  static Future<List<FileItem>> listFiles(String driveId, {String folderId = 'root'}) async {
    final headers = await AuthService.getAuthHeaders();
    
    String endpoint;
    if (driveId == 'shared') {
      endpoint = '$baseUrl/shared/list?folder_id=$folderId';
    } else {
      endpoint = '$baseUrl/user/list-files/$driveId?folder_id=$folderId';
    }
    
    final response = await http.get(Uri.parse(endpoint), headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['files'] as List).map((file) => FileItem.fromJson(file)).toList();
    } else {
      throw Exception('Failed to load files');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String driveId, String filePath, String fileName, {String folderId = 'root'}) async {
    final headers = await AuthService.getAuthHeaders();
    headers.remove('Content-Type');
    
    String endpoint;
    if (driveId == 'shared') {
      endpoint = '$baseUrl/shared/upload';
    } else {
      endpoint = '$baseUrl/user/upload-file/$driveId?folder_id=$folderId';
    }
    
    final request = http.MultipartRequest('POST', Uri.parse(endpoint));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Upload failed');
    }
  }

  static Future<void> deleteFile(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    String endpoint;
    if (driveId == 'shared') {
      endpoint = '$baseUrl/shared/delete/$fileId';
    } else {
      endpoint = '$baseUrl/user/delete-file/$driveId/$fileId';
    }
    
    final response = await http.delete(Uri.parse(endpoint), headers: headers);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Delete failed');
    }
  }

  static Future<String> shareFile(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    String endpoint;
    if (driveId == 'shared') {
      endpoint = '$baseUrl/shared/share/$fileId';
    } else {
      endpoint = '$baseUrl/user/share-file/$driveId/$fileId';
    }
    
    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({'public': true}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['shared_link'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Share failed');
    }
  }
}