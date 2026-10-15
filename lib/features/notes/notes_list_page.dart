import 'package:flutter/material.dart';

import 'note_database.dart';
import 'note.dart';
import 'note_edit_page.dart';

/// 记事本：需求 / 想法记录列表
class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final notes = await NoteDatabase.instance.getAll();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return hm;
    }
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} $hm';
  }

  Future<void> _openEdit([Note? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NoteEditPage(note: note)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记事本')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_add_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('还没有笔记\n点击右下角 + 记录你的想法',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _notes.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Dismissible(
                      key: ValueKey(note.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        await NoteDatabase.instance.delete(note.id!);
                        _refresh();
                      },
                      child: ListTile(
                        title: Text(
                          note.title.isEmpty ? '（无标题）' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          note.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _fmtTime(note.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _openEdit(note),
                      ),
                    );
                  },
                ),
    );
  }
}
