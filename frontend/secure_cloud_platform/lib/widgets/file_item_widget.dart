import 'package:flutter/material.dart';
import '../models/drive_model.dart';
import '../services/search_service.dart';
import 'share_dialog.dart';

class FileItemWidget extends StatefulWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String driveId;
  final bool showFavorite;

  const FileItemWidget({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.driveId,
    this.showFavorite = true,
  });

  @override
  State<FileItemWidget> createState() => _FileItemWidgetState();
}

class _FileItemWidgetState extends State<FileItemWidget> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.file.sharedLink != null; // Placeholder logic
  }

  IconData _getFileIcon() {
    if (widget.file.isFolder) return Icons.folder;
    
    final mimeType = widget.file.mimeType?.toLowerCase() ?? '';
    if (mimeType.contains('image')) return Icons.image;
    if (mimeType.contains('video')) return Icons.video_file;
    if (mimeType.contains('audio')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('text') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('spreadsheet')) return Icons.table_chart;
    if (mimeType.contains('presentation')) return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    if (widget.file.isFolder) return Colors.blue;
    
    final mimeType = widget.file.mimeType?.toLowerCase() ?? '';
    if (mimeType.contains('image')) return Colors.green;
    if (mimeType.contains('video')) return Colors.red;
    if (mimeType.contains('audio')) return Colors.purple;
    if (mimeType.contains('pdf')) return Colors.red[700]!;
    if (mimeType.contains('text') || mimeType.contains('document')) return Colors.blue[700]!;
    if (mimeType.contains('spreadsheet')) return Colors.green[700]!;
    if (mimeType.contains('presentation')) return Colors.orange[700]!;
    return Colors.grey;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await SearchService.toggleFavorite(widget.driveId, widget.file.id);
      setState(() => _isFavorite = !_isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: widget.isSelected ? 4 : 1,
      color: widget.isSelected ? Colors.deepPurple[50] : null,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getFileColor().withValues(alpha: 0.1),
              child: Icon(_getFileIcon(), color: _getFileColor()),
            ),
            if (widget.isSelected)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          widget.file.name,
          style: TextStyle(
            fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.file.size != null && !widget.file.isFolder)
                  Text(
                    widget.file.formattedSize,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                if (widget.file.size != null && !widget.file.isFolder && widget.file.sharedLink != null)
                  const Text(' • ', style: TextStyle(color: Colors.grey)),
                if (widget.file.sharedLink != null)
                  Text(
                    'Shared',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (widget.file.modifiedTime != null)
              Text(
                _formatDate(widget.file.modifiedTime),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: !widget.file.isFolder
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.file.sharedLink != null)
                    const Icon(Icons.link, color: Colors.green, size: 16),
                  if (widget.showFavorite)
                    IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'share') {
                        showDialog(
                          context: context,
                          builder: (context) => ShareDialog(
                            file: widget.file,
                            driveId: widget.driveId,
                          ),
                        );
                      } else if (value == 'favorite') {
                        _toggleFavorite();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(
                              widget.file.sharedLink != null ? Icons.link_off : Icons.share,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(widget.file.sharedLink != null ? 'Manage Share' : 'Share'),
                          ],
                        ),
                      ),
                      if (widget.showFavorite)
                        PopupMenuItem(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(
                                _isFavorite ? Icons.favorite_border : Icons.favorite,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(_isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                            ],
                          ),
                        ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        selected: widget.isSelected,
      ),
    );
  }
}