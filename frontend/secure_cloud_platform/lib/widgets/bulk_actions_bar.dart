import 'package:flutter/material.dart';

class BulkActionsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onClear;
  final VoidCallback? onAddToFavorites;

  const BulkActionsBar({
    super.key,
    required this.selectedCount,
    required this.onDelete,
    required this.onShare,
    required this.onDownload,
    required this.onClear,
    this.onAddToFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        border: Border(
          top: BorderSide(color: Colors.deepPurple[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.deepPurple[600]),
          const SizedBox(width: 8),
          Text(
            '$selectedCount selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple[800],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDownload,
            icon: const Icon(Icons.download),
            tooltip: 'Download',
          ),
          if (onAddToFavorites != null)
            IconButton(
              onPressed: onAddToFavorites,
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Add to Favorites',
            ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share),
            tooltip: 'Share',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete',
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Selection',
          ),
        ],
      ),
    );
  }
}