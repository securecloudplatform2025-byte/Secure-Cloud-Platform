import 'package:flutter/material.dart';
import '../models/drive_model.dart';

class DriveSelector extends StatelessWidget {
  final List<Drive> drives;
  final Drive? selectedDrive;
  final Function(Drive) onDriveChanged;

  const DriveSelector({
    super.key,
    required this.drives,
    required this.selectedDrive,
    required this.onDriveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Drive>(
                value: selectedDrive,
                isExpanded: true,
                items: drives.map((drive) {
                  return DropdownMenuItem<Drive>(
                    value: drive,
                    child: Row(
                      children: [
                        Icon(
                          drive.type == 'shared' ? Icons.cloud : Icons.person,
                          size: 20,
                          color: drive.type == 'shared' ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            drive.name,
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (drive) {
                  if (drive != null) {
                    onDriveChanged(drive);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}