import 'package:flutter/material.dart';
import 'package:fitness_planner/domain/models/exercise_library.dart';
import 'package:fitness_planner/theme/app_theme.dart';

void showExerciseLibraryPicker({
  required BuildContext context,
  required void Function(LibraryExercise) onSelected,
  required VoidCallback onBlank,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseLibrarySheet(
      onSelected: onSelected,
      onBlank: onBlank,
    ),
  );
}

class _ExerciseLibrarySheet extends StatefulWidget {
  final void Function(LibraryExercise) onSelected;
  final VoidCallback onBlank;

  const _ExerciseLibrarySheet({
    required this.onSelected,
    required this.onBlank,
  });

  @override
  State<_ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends State<_ExerciseLibrarySheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LibraryExercise> get _filtered {
    if (_query.isEmpty) return kExerciseLibrary;
    final q = _query.toLowerCase();
    return kExerciseLibrary
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final filtered = _filtered;

    final grouped = <String, List<LibraryExercise>>{};
    if (_query.isEmpty) {
      for (final e in filtered) {
        grouped.putIfAbsent(e.category, () => []).add(e);
      }
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(kRadius + 8)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              style: bodyStyle(fontSize: 15, color: c.ink),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: bodyStyle(fontSize: 15, color: c.inkMute),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: c.inkMute),
                filled: true,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadius - 4),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              children: [
                // "Type my own" always at the top
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onBlank();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius:
                            BorderRadius.circular(kRadius - 4),
                        border: Border.all(color: c.hairlineSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 16, color: c.inkDim),
                          const SizedBox(width: 10),
                          Text(
                            'Type my own',
                            style: bodyStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.inkDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_query.isEmpty) ...[
                  for (final category in grouped.keys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Text(
                        category.toUpperCase(),
                        style: bodyStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.inkMute,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    ...grouped[category]!.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _LibraryTile(
                            exercise: e,
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelected(e);
                            },
                          ),
                        )),
                  ],
                ] else if (filtered.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No exercises found',
                        style:
                            bodyStyle(fontSize: 14, color: c.inkMute),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  ...filtered.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LibraryTile(
                          exercise: e,
                          showCategory: true,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelected(e);
                          },
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final LibraryExercise exercise;
  final bool showCategory;
  final VoidCallback onTap;

  const _LibraryTile({
    required this.exercise,
    this.showCategory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeData.of(context).c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(kRadius - 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: bodyStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                  if (showCategory) ...[
                    const SizedBox(height: 2),
                    Text(
                      exercise.category,
                      style: bodyStyle(
                          fontSize: 12, color: c.inkMute),
                    ),
                  ],
                ],
              ),
            ),
            if (exercise.isTimed)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⏱ Timed',
                  style: bodyStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.inkDim,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
