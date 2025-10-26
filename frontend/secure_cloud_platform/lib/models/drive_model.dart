class Drive {
  final String id;
  final String name;
  final String type; // 'shared' or 'personal'
  final DateTime createdAt;

  Drive({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  factory Drive.fromJson(Map<String, dynamic> json) {
    return Drive(
      id: json['id'],
      name: json['drive_name'] ?? json['name'],
      type: json['drive_type'] ?? 'shared',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FileItem {
  final String id;
  final String name;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedTime;
  final List<String>? parents;
  final String? sharedLink;
  final bool isFolder;

  FileItem({
    required this.id,
    required this.name,
    this.mimeType,
    this.size,
    this.modifiedTime,
    this.parents,
    this.sharedLink,
    required this.isFolder,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['id'],
      name: json['name'],
      mimeType: json['mimeType'],
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
      modifiedTime: json['modifiedTime'] != null ? DateTime.parse(json['modifiedTime']) : null,
      parents: json['parents']?.cast<String>(),
      sharedLink: json['shared_link'],
      isFolder: json['mimeType'] == 'application/vnd.google-apps.folder',
    );
  }

  String get formattedSize {
    if (size == null) return '';
    if (size! < 1024) return '${size}B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)}KB';
    if (size! < 1024 * 1024 * 1024) return '${(size! / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}