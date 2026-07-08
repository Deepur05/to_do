import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// SQL to run once in Supabase -> SQL editor:
//
// create table todos (
//   id uuid primary key default gen_random_uuid(),
//   title text not null,
//   description text,
//   is_done boolean default false,
//   created_at timestamp with time zone default now()
// );
//
// alter table todos enable row level security;
// create policy "public access" on todos for all using (true) with check (true);
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E5DF7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

// =============================================================================
// HOME PAGE
// =============================================================================

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _openAddTodoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // lets the sheet grow with the keyboard
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTodoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8D5F5), Color(0xFFFCE4EC)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbFieldPainter(_bgController.value),
                size: Size.infinite,
              );
            },
          ),
          // ---- Foreground content: the todo list ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: const TodoList(),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E5DF7), Color(0xFFE85DC0)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E5DF7).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _openAddTodoSheet,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints several softly glowing, rotating "orbs" with a fake 3D wobble
/// (via Matrix4 perspective) — gives a stunning animated look without
/// needing any external 3D packages.
class _OrbFieldPainter extends CustomPainter {
  final double t; // 0..1 animation progress

  _OrbFieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _OrbSpec(
        color: const Color(0xFFD4A5F0),
        radiusFactor: 0.35,
        speed: 1.0,
        phase: 0,
      ),
      _OrbSpec(
        color: const Color(0xFFF5B8D0),
        radiusFactor: 0.25,
        speed: 1.6,
        phase: 2.1,
      ),
      _OrbSpec(
        color: const Color(0xFFC9A0F7),
        radiusFactor: 0.20,
        speed: 0.7,
        phase: 4.2,
      ),
    ];

    for (final orb in orbs) {
      final angle = 2 * math.pi * t * orb.speed + orb.phase;
      final cx = size.width / 2 + math.cos(angle) * size.width * 0.28;
      final cy = size.height * 0.28 + math.sin(angle) * size.height * 0.10;

      // Fake perspective "3D" scale pulse
      final depth = 0.85 + 0.15 * math.sin(angle * 1.3);
      final radius = size.shortestSide * orb.radiusFactor * depth;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: 0.35 * depth),
            orb.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbFieldPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _OrbSpec {
  final Color color;
  final double radiusFactor;
  final double speed;
  final double phase;

  _OrbSpec({
    required this.color,
    required this.radiusFactor,
    required this.speed,
    required this.phase,
  });
}

// =============================================================================
// TODO LIST — streams live from Supabase
// =============================================================================

class TodoList extends StatelessWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final todos = snapshot.data ?? [];
        if (todos.isEmpty) {
          return const Center(
            child: Text(
              'No tasks yet.\nTap + to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B6B7D), fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _TodoCard(todo: todo);
          },
        );
      },
    );
  }
}

class _TodoCard extends StatelessWidget {
  final Map<String, dynamic> todo;

  const _TodoCard({required this.todo});

  Future<void> _toggleDone(BuildContext context) async {
    await supabase
        .from('todos')
        .update({'is_done': !(todo['is_done'] as bool)})
        .eq('id', todo['id']);
  }

  Future<void> _delete(BuildContext context) async {
    await supabase.from('todos').delete().eq('id', todo['id']);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDone = todo['is_done'] as bool? ?? false;

    return Dismissible(
      key: ValueKey(todo['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isDone,
              onChanged: (_) => _toggleDone(context),
              shape: const CircleBorder(),
              activeColor: const Color(0xFF8E5DF7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo['title'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if ((todo['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      todo['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isDone ? Colors.grey.shade400 : const Color(0xFF6B6B7D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ADD TODO BOTTOM SHEET
// =============================================================================

class AddTodoSheet extends StatefulWidget {
  const AddTodoSheet({super.key});

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onSavePressed() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    // Show confirmation alert dialog before saving
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save task?'),
        content: Text('Title: $title\n\nDo you want to save this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      await supabase.from('todos').insert({
        'title': title,
        'description': _descController.text.trim(),
        'is_done': false,
      });

      if (mounted) Navigator.of(context).pop(); // close the bottom sheet
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding.viewInsets pushes the sheet up above the keyboard.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'New Task',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8E5DF7)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8E5DF7)),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E5DF7), Color(0xFFE85DC0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving ? null : _onSavePressed,
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
