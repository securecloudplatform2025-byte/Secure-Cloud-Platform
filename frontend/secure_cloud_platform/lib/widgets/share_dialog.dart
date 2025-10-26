import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drive_model.dart';
import '../services/api_service.dart';

class ShareDialog extends StatefulWidget {
  final FileItem file;
  final String driveId;

  const ShareDialog({
    super.key,
    required this.file,
    required this.driveId,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  bool _allowDownload = true;
  int? _expiresInDays;
  String? _shareLink;
  bool _isLoading = false;
  bool _isShared = false;

  final List<int> _expirationOptions = [1, 7, 30, 90];

  @override
  void initState() {
    super.initState();
    _isShared = widget.file.sharedLink != null;
    _shareLink = widget.file.sharedLink;
  }

  Future<void> _generateShareLink() async {
    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic> result;
      
      if (widget.driveId == 'shared') {
        result = await ApiService.shareSharedFile(
          widget.file.id,
          expiresInDays: _expiresInDays,
          allowDownload: _allowDownload,
        );
      } else {
        result = await ApiService.shareUserFile(
          widget.driveId,
          widget.file.id,
          expiresInDays: _expiresInDays,
          allowDownload: _allowDownload,
        );
      }
      
      setState(() {
        _shareLink = result['shared_link'];
        _isShared = true;
      });
      
      _showSuccess('Share link generated successfully');
    } catch (e) {
      _showError('Failed to generate share link: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeShareLink() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.driveId == 'shared') {
        await ApiService.revokeSharedShare(widget.file.id);
      } else {
        await ApiService.revokeUserShare(widget.driveId, widget.file.id);
      }
      
      setState(() {
        _shareLink = null;
        _isShared = false;
      });
      
      _showSuccess('Share link revoked successfully');
    } catch (e) {
      _showError('Failed to revoke share link: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_shareLink != null) {
      await Clipboard.setData(ClipboardData(text: _shareLink!));
      _showSuccess('Link copied to clipboard');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.share, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Share "${widget.file.name}"',
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isShared) ...[
              const Text('Share Settings:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              CheckboxListTile(
                title: const Text('Allow Download'),
                subtitle: const Text('Users can download the file'),
                value: _allowDownload,
                onChanged: (value) => setState(() => _allowDownload = value ?? true),
              ),
              
              const SizedBox(height: 8),
              const Text('Link Expiration:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Never'),
                    selected: _expiresInDays == null,
                    onSelected: (selected) => setState(() => _expiresInDays = null),
                  ),
                  ..._expirationOptions.map((days) => ChoiceChip(
                    label: Text('${days}d'),
                    selected: _expiresInDays == days,
                    onSelected: (selected) => setState(() => _expiresInDays = days),
                  )),
                ],
              ),
            ],
            
            if (_isShared) ...[
              const Text('Share Link:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shareLink ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isShared)
          TextButton(
            onPressed: _isLoading ? null : _revokeShareLink,
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!_isShared)
          ElevatedButton(
            onPressed: _isLoading ? null : _generateShareLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate Link'),
          ),
      ],
    );
  }
}