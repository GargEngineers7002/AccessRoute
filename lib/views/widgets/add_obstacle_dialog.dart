import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../models/obstacle.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/obstacle_provider.dart';

/// A modal bottom sheet for reporting a new accessibility obstacle.
class AddObstacleDialog extends ConsumerStatefulWidget {
  /// Creates the dialog for the given map [position].
  const AddObstacleDialog({super.key, required this.position});

  /// The geographic position where the obstacle was tapped.
  final LatLng position;

  @override
  ConsumerState<AddObstacleDialog> createState() => _AddObstacleDialogState();
}

class _AddObstacleDialogState extends ConsumerState<AddObstacleDialog> {
  final _titleController = TextEditingController();
  ObstacleType _selectedType = ObstacleType.stairs;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final obstacle = Obstacle(
      id: const Uuid().v4(),
      position: widget.position,
      title: _titleController.text.trim().isEmpty
          ? _selectedType.label
          : _titleController.text.trim(),
      type: _selectedType,
      reportedAt: DateTime.now(),
    );

    ref.read(obstacleProvider.notifier).addObstacle(obstacle);
    ref.read(navigationProvider.notifier).recalculateRoute();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Report Obstacle',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.position.latitude.toStringAsFixed(5)}, '
            '${widget.position.longitude.toStringAsFixed(5)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),

          // Obstacle type chips
          Text(
            'Type',
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ObstacleType.values.map((type) {
              final isSelected = type == _selectedType;
              return ChoiceChip(
                label: Text('${type.emoji}  ${type.label}'),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: const Color(0xFF253547),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.white24,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Title field
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF253547),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Report Obstacle'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
