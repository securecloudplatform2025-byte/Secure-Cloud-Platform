import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> connectDrive(String driveType, String accessToken, String refreshToken, String driveName) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/connect-drive'),
      headers: headers,
      body: jsonEncode({
        'drive_type': driveType,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'drive_name': driveName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to connect drive');
    }
  }

  static Future<List<dynamic>> listFiles() async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/list-files'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['files'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to list files');
    }
  }

  static Future<Map<String, dynamic>> uploadToShared(String filePath, String fileName) async {
    final headers = await AuthService.getAuthHeaders();
    final Map<String, String> requestHeaders = Map.from(headers);
    requestHeaders.remove('Content-Type');
    
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/shared/upload'));
    request.headers.addAll(requestHeaders);
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

  static Future<void> downloadFromShared(String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/shared/download/$fileId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Download failed');
    }
  }

  static Future<Map<String, dynamic>> deleteFromShared(String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/shared/delete/$fileId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Delete failed');
    }
  }

  static Future<Map<String, dynamic>> connectUserDrive(String authCode, String driveName) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/user/connect-drive'),
      headers: headers,
      body: jsonEncode({
        'authorization_code': authCode,
        'drive_name': driveName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Drive connection failed');
    }
  }

  static Future<List<dynamic>> listUserFiles(String driveId, {String folderId = 'root'}) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/user/list-files/$driveId?folder_id=$folderId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['files'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to list files');
    }
  }

  static Future<Map<String, dynamic>> uploadToUserDrive(String driveId, String filePath, String fileName, {String folderId = 'root'}) async {
    final headers = await AuthService.getAuthHeaders();
    final Map<String, String> requestHeaders = Map.from(headers);
    requestHeaders.remove('Content-Type');
    
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/user/upload-file/$driveId?folder_id=$folderId'));
    request.headers.addAll(requestHeaders);
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

  static Future<void> downloadFromUserDrive(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/user/download-file/$driveId/$fileId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Download failed');
    }
  }

  static Future<Map<String, dynamic>> deleteFromUserDrive(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.delete(
      Uri.parse('$baseUrl/user/delete-file/$driveId/$fileId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Delete failed');
    }
  }

  static Future<Map<String, dynamic>> shareUserFile(String driveId, String fileId, {int? expiresInDays, bool allowDownload = true}) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/user/share-file/$driveId/$fileId'),
      headers: headers,
      body: jsonEncode({
        'public': true,
        'expires_in_days': expiresInDays,
        'allow_download': allowDownload,
        'allow_view': true,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Share failed');
    }
  }

  static Future<Map<String, dynamic>> shareSharedFile(String fileId, {int? expiresInDays, bool allowDownload = true}) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/shared/share/$fileId'),
      headers: headers,
      body: jsonEncode({
        'public': true,
        'expires_in_days': expiresInDays,
        'allow_download': allowDownload,
        'allow_view': true,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Share failed');
    }
  }

  static Future<void> revokeUserShare(String driveId, String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/user/revoke/$driveId/$fileId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Revoke failed');
    }
  }

  static Future<void> revokeSharedShare(String fileId) async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/shared/revoke/$fileId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Revoke failed');
    }
  }

  static Future<List<dynamic>> getSharedFiles() async {
    final headers = await AuthService.getAuthHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/user/shared-files'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['shared_files'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get shared files');
    }
  }
}