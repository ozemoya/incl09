// Myles Miller — In-Class Activity 08, Fall Festival Roster.
import 'package:flutter/material.dart';

import 'catalogue_screen.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(FestivalApp(helper: helper));
}

class FestivalApp extends StatelessWidget {
  const FestivalApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fall Festival Roster',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B4A23)),
      useMaterial3: true,
    ),
    home: HomeShell(helper: helper),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            RosterScreen(helper: widget.helper),
            CatalogueScreen(helper: widget.helper),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'Guests'),
            NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Catalogue'),
          ],
        ),
      );
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  int _count = 0;
  int? _editingId;
  bool _busy = false;
  bool _loading = true;
  String? _readError;
  String? _nameError;
  String? _ageError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loading = true;
      _readError = null;
    });
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Roster read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _readError = 'Could not read guests. Tap Refresh to retry.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _editingId = null;
    _nameError = null;
    _ageError = null;
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Enter a guest name.' : null;
      _ageError = age == null
          ? 'Enter a whole-number age.'
          : age < 0 || age > 130
          ? 'Age must be from 0 to 130.'
          : null;
      _feedback = _nameError != null || _ageError != null
          ? 'Nothing saved. Correct the highlighted field.'
          : null;
    });
    return _nameError == null && _ageError == null;
  }

  Future<void> _save() async {
    if (_busy || !_validate()) return;
    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    final selectedId = _editingId;
    setState(() => _busy = true);
    try {
      final result = selectedId == null
          ? await widget.helper.insert({
              DatabaseHelper.columnName: name,
              DatabaseHelper.columnAge: age,
            })
          : await widget.helper.update({
              DatabaseHelper.columnId: selectedId,
              DatabaseHelper.columnName: name,
              DatabaseHelper.columnAge: age,
            });
      if (!mounted) return;
      if (selectedId != null && result == 0) {
        setState(
          () => _feedback =
              'Guest ID $selectedId no longer exists. Refreshing the roster.',
        );
        await _refreshAfterWrite();
        return;
      }
      setState(() {
        _clearForm();
        _feedback = selectedId == null
            ? 'Added guest ID $result.'
            : 'Updated guest ID $selectedId ($result row).';
      });
      await _refreshAfterWrite();
    } catch (error, stackTrace) {
      debugPrint('Roster save failed: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _feedback = 'Save failed. Check the fields and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Called only after a database write has completed; never repeats the write.
  Future<void> _refreshAfterWrite() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Refresh after write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _readError =
            'Saved, but refresh failed. Tap Refresh to read the roster.';
        _feedback = _readError;
      });
    }
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _nameError = null;
      _ageError = null;
      _feedback =
          'Editing guest ID $_editingId. Cancel edit makes no database change.';
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Remove $name (ID $id) from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      final affected = await widget.helper.delete(id);
      if (!mounted) return;
      setState(() {
        if (affected == 1 && _editingId == id) _clearForm();
        _feedback = affected == 1
            ? 'Deleted guest ID $id ($affected row).'
            : 'Guest ID $id no longer exists. Refreshing the roster.';
      });
      await _refreshAfterWrite();
    } catch (error, stackTrace) {
      debugPrint('Roster delete failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _feedback = 'Delete failed. Try Refresh, then retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fall Festival Roster')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Guest details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: 'Name',
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ageController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age',
              border: const OutlineInputBorder(),
              errorText: _ageError,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: Icon(_editingId == null ? Icons.person_add : Icons.save),
                label: Text(
                  _editingId == null ? 'Add guest' : 'Save ID $_editingId',
                ),
              ),
              OutlinedButton(
                onPressed: _busy || _editingId == null
                    ? null
                    : () => setState(() {
                        _clearForm();
                        _feedback = 'Edit canceled. No row changed.';
                      }),
                child: const Text('Cancel edit'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _loadRows,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_feedback!, key: const Key('feedback')),
            ),
          const Divider(height: 30),
          Text(
            'Guests ($_count)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _readError != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_readError!, key: const Key('read-error')),
            ),
          if (!_loading && _readError == null && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No festival guests yet. Add the first guest above.'),
            ),
          if (!_loading && _readError == null)
            for (final row in _rows)
              Card(
                child: ListTile(
                  title: Text(row[DatabaseHelper.columnName] as String),
                  subtitle: Text(
                    'ID ${row[DatabaseHelper.columnId]} · Age ${row[DatabaseHelper.columnAge]}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit ID ${row[DatabaseHelper.columnId]}',
                        onPressed: _busy ? null : () => _edit(row),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete ID ${row[DatabaseHelper.columnId]}',
                        onPressed: _busy ? null : () => _delete(row),
                        icon: const Icon(Icons.delete_outline),
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
