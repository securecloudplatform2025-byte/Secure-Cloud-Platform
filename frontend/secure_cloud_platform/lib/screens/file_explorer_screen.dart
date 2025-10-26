import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/drive_model.dart';
import '../services/file_service.dart';
import '../widgets/file_item_widget.dart';
import '../widgets/drive_selector.dart';
import '../widgets/drag_drop_area.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/progress_overlay.dart';
import '../widgets/bulk_actions_bar.dart';
import '../screens/recent_files_screen.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  List<Drive> drives = [];
  Drive? selectedDrive;
  List<FileItem> files = [];
  List<FileItem> searchResults = [];
  List<String> folderPath = ['root'];
  List<String> folderNames = ['Home'];
  bool isLoading = false;
  Set<String> selectedFiles = {};
  bool isSelectionMode = false;
  bool isSearchMode = false;
  final ProgressNotifier _progressNotifier = ProgressNotifier();

  @override
  void initState() {
    super.initState();
    _loadDrives();
  }

  Future<void> _loadDrives() async {
    setState(() => isLoading = true);
    try {
      drives = await FileService.getUserDrives();
      if (drives.isNotEmpty) {
        selectedDrive = drives.first;
        await _loadFiles();
      }
    } catch (e) {
      _showError('Failed to load drives: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    if (selectedDrive == null) return;
    
    setState(() => isLoading = true);
    try {
      files = await FileService.listFiles(
        selectedDrive!.id,
        folderId: folderPath.last,
      );
    } catch (e) {
      _showError('Failed to load files: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _navigateToFolder(FileItem folder) {
    setState(() {
      folderPath.add(folder.id);
      folderNames.add(folder.name);
      selectedFiles.clear();
      isSelectionMode = false;
    });
    _loadFiles();
  }

  void _navigateBack() {
    if (folderPath.length > 1) {
      setState(() {
        folderPath.removeLast();
        folderNames.removeLast();
        selectedFiles.clear();
        isSelectionMode = false;
      });
      _loadFiles();
    }
  }

  Future<void> _uploadFiles() async {
    if (selectedDrive == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    
    if (result != null) {
      await _uploadFileList(result.files.map((f) => f.path!).toList());
    }
  }

  Future<void> _uploadFileList(List<String> filePaths) async {
    if (selectedDrive == null) return;

    _progressNotifier.show(
      title: 'Uploading Files',
      subtitle: '0 of ${filePaths.length} files',
      progress: 0.0,
    );
    
    for (int i = 0; i < filePaths.length; i++) {
      try {
        final fileName = filePaths[i].split('/').last;
        _progressNotifier.updateProgress(
          (i + 1) / filePaths.length,
          subtitle: '${i + 1} of ${filePaths.length} files - $fileName',
        );
        
        await FileService.uploadFile(
          selectedDrive!.id,
          filePaths[i],
          fileName,
          folderId: folderPath.last,
        );
      } catch (e) {
        _showError('Failed to upload ${filePaths[i].split('/').last}: $e');
      }
    }
    
    _progressNotifier.hide();
    await _loadFiles();
    _showSuccess('Files uploaded successfully');
  }

  Future<void> _deleteSelectedFiles() async {
    if (selectedFiles.isEmpty || selectedDrive == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Delete ${selectedFiles.length} file(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _progressNotifier.show(
        title: 'Deleting Files',
        subtitle: '0 of ${selectedFiles.length} files',
        progress: 0.0,
      );
      
      int completed = 0;
      for (String fileId in selectedFiles) {
        try {
          await FileService.deleteFile(selectedDrive!.id, fileId);
          completed++;
          _progressNotifier.updateProgress(
            completed / selectedFiles.length,
            subtitle: '$completed of ${selectedFiles.length} files',
          );
        } catch (e) {
          _showError('Failed to delete file: $e');
        }
      }
      
      _progressNotifier.hide();
      setState(() {
        selectedFiles.clear();
        isSelectionMode = false;
      });
      
      await _loadFiles();
      _showSuccess('Files deleted successfully');
    }
  }

  void _toggleFileSelection(String fileId) {
    setState(() {
      if (selectedFiles.contains(fileId)) {
        selectedFiles.remove(fileId);
      } else {
        selectedFiles.add(fileId);
      }
      isSelectionMode = selectedFiles.isNotEmpty;
    });
  }

  void _onSearchResults(List<FileItem> results) {
    setState(() {
      searchResults = results;
      isSearchMode = true;
      selectedFiles.clear();
      isSelectionMode = false;
    });
  }

  void _clearSearch() {
    setState(() {
      isSearchMode = false;
      searchResults.clear();
      selectedFiles.clear();
      isSelectionMode = false;
    });
  }

  Future<void> _bulkDownload() async {
    _showSuccess('Bulk download started');
  }

  Future<void> _bulkShare() async {
    _showSuccess('Bulk share completed');
  }

  Future<void> _addToFavorites() async {
    _showSuccess('Added to favorites');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Explorer'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecentFilesScreen()),
            ),
            icon: const Icon(Icons.history),
          ),
          if (!isSelectionMode)
            IconButton(
              onPressed: _uploadFiles,
              icon: const Icon(Icons.upload_file),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              custom.SearchBar(
                onSearchResults: _onSearchResults,
                onClearSearch: _clearSearch,
              ),
              
              // Drive Selector
              if (!isSearchMode)
                DriveSelector(
                  drives: drives,
                  selectedDrive: selectedDrive,
                  onDriveChanged: (drive) {
                    setState(() {
                      selectedDrive = drive;
                      folderPath = ['root'];
                      folderNames = ['Home'];
                      selectedFiles.clear();
                      isSelectionMode = false;
                    });
                    _loadFiles();
                  },
                ),
          
              // Breadcrumb Navigation
              if (!isSearchMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (folderPath.length > 1)
                        IconButton(
                          onPressed: _navigateBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: folderNames.asMap().entries.map((entry) {
                              int index = entry.key;
                              String name = entry.value;
                              return Row(
                                children: [
                                  if (index > 0) const Icon(Icons.chevron_right),
                                  TextButton(
                                    onPressed: index < folderNames.length - 1
                                        ? () {
                                            setState(() {
                                              folderPath = folderPath.sublist(0, index + 1);
                                              folderNames = folderNames.sublist(0, index + 1);
                                              selectedFiles.clear();
                                              isSelectionMode = false;
                                            });
                                            _loadFiles();
                                          }
                                        : null,
                                    child: Text(name),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          
              // File List with Drag & Drop
              Expanded(
                child: DragDropArea(
                  onFilesDropped: _uploadFileList,
                  child: _buildFileList(),
                ),
              ),
              
              // Bulk Actions Bar
              if (isSelectionMode)
                BulkActionsBar(
                  selectedCount: selectedFiles.length,
                  onDelete: _deleteSelectedFiles,
                  onShare: _bulkShare,
                  onDownload: _bulkDownload,
                  onClear: () => setState(() {
                    selectedFiles.clear();
                    isSelectionMode = false;
                  }),
                  onAddToFavorites: _addToFavorites,
                ),
            ],
          ),
          
          // Progress Overlay
          AnimatedBuilder(
            animation: _progressNotifier,
            builder: (context, child) {
              if (!_progressNotifier.isVisible) return const SizedBox.shrink();
              return ProgressOverlay(
                title: _progressNotifier.title,
                subtitle: _progressNotifier.subtitle,
                progress: _progressNotifier.progress,
                onCancel: _progressNotifier.onCancel,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    final currentFiles = isSearchMode ? searchResults : files;
    
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearchMode ? Icons.search_off : Icons.folder_open,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isSearchMode ? 'No search results' : 'No files found',
              style: const TextStyle(color: Colors.grey),
            ),
            if (!isSearchMode) ...[
              const SizedBox(height: 8),
              const Text(
                'Drag files here or use the upload button',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ]
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (constraints.maxWidth / 300).floor(),
              childAspectRatio: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: currentFiles.length,
            itemBuilder: (context, index) => _buildFileItem(currentFiles[index]),
          );
        } else {
          return ListView.builder(
            itemCount: currentFiles.length,
            itemBuilder: (context, index) => _buildFileItem(currentFiles[index]),
          );
        }
      },
    );
  }

  Widget _buildFileItem(FileItem file) {
    return FileItemWidget(
      file: file,
      isSelected: selectedFiles.contains(file.id),
      onTap: file.isFolder && !isSearchMode
          ? () => _navigateToFolder(file)
          : () => _toggleFileSelection(file.id),
      onLongPress: () => _toggleFileSelection(file.id),
      driveId: selectedDrive?.id ?? 'search',
    );
  }
}