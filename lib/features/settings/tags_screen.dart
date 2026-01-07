import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Tags"),
        backgroundColor: AppTheme.backgroundBlack,
      ),
      body: SafeArea(
        child: tagsAsync.when(
          data: (tags) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                tileColor: AppTheme.surfaceGrey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: Color(tag.colorHex),
                  radius: 12,
                ),
                title: Text(tag.name, style: const TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.textGrey, size: 20),
                      onPressed: () => _showTagEditor(context, ref, tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteTag(context, ref, tag),
                    ),
                  ],
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        onPressed: () {
          HapticFeedback.heavyImpact();
          _showTagEditor(context, ref, null);
        },
        child: const Icon(Icons.add, color: AppTheme.backgroundBlack),
      ),
    );
  }

  void _showTagEditor(BuildContext context, WidgetRef ref, Tag? tag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGrey,
      builder: (context) => _TagEditorModal(tag: tag),
    );
  }

  void _deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text("Delete Tag", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${tag.name}'?", style: const TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(financeServiceProvider).deleteTag(tag.id);
      ref.invalidate(tagsProvider);
    }
  }
}

class _TagEditorModal extends StatefulWidget {
  final Tag? tag;
  const _TagEditorModal({this.tag});

  @override
  State<_TagEditorModal> createState() => _TagEditorModalState();
}

class _TagEditorModalState extends State<_TagEditorModal> {
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF4CAF50;

  final List<int> _colors = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7, 0xFF3F51B5,
    0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4, 0xFF009688, 0xFF4CAF50,
    0xFF8BC34A, 0xFFCDDC39, 0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800,
    0xFFFF5722, 0xFF795548, 0xFF9E9E9E, 0xFF607D8B,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      _nameController.text = widget.tag!.name;
      _selectedColor = widget.tag!.colorHex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tag != null ? "Edit Tag" : "New Tag",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Tag Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Color", style: TextStyle(color: AppTheme.textGrey)),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: _selectedColor == color
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                final service = ref.read(financeServiceProvider);
                final navigator = Navigator.of(context);

                final userId =
                    Supabase.instance.client.auth.currentUser?.id ?? 'local';
                if (widget.tag != null) {
                  await service.updateTag(Tag(
                    id: widget.tag!.id,
                      userId: userId,
                    name: name,
                    colorHex: _selectedColor,
                  ));
                } else {
                  await service.addTag(Tag(
                    id: const Uuid().v4(),
                      userId: userId,
                    name: name,
                    colorHex: _selectedColor,
                  ));
                }
                ref.invalidate(tagsProvider);
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.tag != null ? "Update Tag" : "Create Tag",
                style: const TextStyle(color: AppTheme.backgroundBlack, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
