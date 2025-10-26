import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DragDropArea extends StatefulWidget {
  final Widget child;
  final Function(List<String>) onFilesDropped;

  const DragDropArea({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  @override
  State<DragDropArea> createState() => _DragDropAreaState();
}

class _DragDropAreaState extends State<DragDropArea> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) {
        final files = detail.files.map((file) => file.path).toList();
        widget.onFilesDropped(files);
        setState(() => _isDragging = false);
      },
      onDragEntered: (detail) {
        setState(() => _isDragging = true);
      },
      onDragExited: (detail) {
        setState(() => _isDragging = false);
      },
      child: Container(
        decoration: _isDragging
            ? BoxDecoration(
                border: Border.all(color: Colors.deepPurple, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withValues(alpha: 0.1),
              )
            : null,
        child: Stack(
          children: [
            widget.child,
            if (_isDragging)
              Container(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 64,
                        color: Colors.deepPurple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Drop files here to upload',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}