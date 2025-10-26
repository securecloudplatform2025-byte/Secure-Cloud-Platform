import 'package:flutter/material.dart';

class ProgressOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onCancel;

  const ProgressOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 24),
                if (progress != null) ...[
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  const SizedBox(height: 8),
                  Text('${(progress! * 100).toInt()}%'),
                ] else
                  const CircularProgressIndicator(),
                if (onCancel != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressNotifier extends ChangeNotifier {
  bool _isVisible = false;
  String _title = '';
  String? _subtitle;
  double? _progress;
  VoidCallback? _onCancel;

  bool get isVisible => _isVisible;
  String get title => _title;
  String? get subtitle => _subtitle;
  double? get progress => _progress;
  VoidCallback? get onCancel => _onCancel;

  void show({
    required String title,
    String? subtitle,
    double? progress,
    VoidCallback? onCancel,
  }) {
    _isVisible = true;
    _title = title;
    _subtitle = subtitle;
    _progress = progress;
    _onCancel = onCancel;
    notifyListeners();
  }

  void updateProgress(double progress, {String? subtitle}) {
    _progress = progress;
    if (subtitle != null) _subtitle = subtitle;
    notifyListeners();
  }

  void hide() {
    _isVisible = false;
    notifyListeners();
  }
}