import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'models.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  final _folderController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _imageController = TextEditingController();
  List<FolderRecord> _folders = const [];
  List<CardRecord> _cards = const [];
  int? _selectedFolderId;
  int? _formFolderId;
  int? _editingCardId;
  String _suit = suits.first;
  bool _busy = false;
  bool _loading = true;
  String? _feedback;
  String? _readError;
  String? _folderError;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _folderController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loading = true;
      _readError = null;
    });
    try {
      await _readRows();
    } catch (error, trace) {
      debugPrint('Catalogue read failed: $error\n$trace');
      if (mounted) {
        setState(() => _readError = 'Could not read the catalogue. Try Refresh.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _readRows() async {
    final folders = await widget.helper.getFoldersWithCounts();
    var selectedId = _selectedFolderId;
    if (selectedId != null && !folders.any((f) => f.id == selectedId)) {
      selectedId = null;
    }
    final cards = selectedId == null
        ? <CardRecord>[]
        : await widget.helper.getCards(selectedId);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _cards = cards;
      _selectedFolderId = selectedId;
      if (_formFolderId != null && !folders.any((f) => f.id == _formFolderId)) {
        _formFolderId = selectedId;
      }
      _readError = null;
    });
  }

  Future<void> _afterWrite() async {
    try {
      await _readRows();
    } catch (error, trace) {
      debugPrint('Catalogue refresh after write failed: $error\n$trace');
      if (mounted) {
        setState(() {
          _readError = 'Saved, but refresh failed. Tap Refresh to read again.';
          _feedback = _readError;
        });
      }
    }
  }

  Future<void> _selectFolder(FolderRecord folder) async {
    if (_busy) return;
    setState(() {
      _selectedFolderId = folder.id;
      _formFolderId = folder.id;
      _feedback = 'Opened ${folder.name} (ID ${folder.id}).';
    });
    await _refresh();
  }

  Future<void> _addFolder() async {
    if (_busy) return;
    final name = _folderController.text.trim();
    setState(() => _folderError = name.isEmpty ? 'Enter a folder name.' : null);
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await widget.helper.insertFolder(name);
      if (!mounted) return;
      setState(() {
        _folderController.clear();
        _selectedFolderId = id;
        _formFolderId = id;
        _feedback = 'Added folder $name (ID $id).';
      });
      await _afterWrite();
    } on DatabaseException catch (error, trace) {
      debugPrint('Folder insert failed: $error\n$trace');
      if (mounted) {
        setState(() {
          _folderError = 'Name already exists or could not be saved.';
          _feedback = 'Folder not saved. Choose a different name.';
        });
      }
    } catch (error, trace) {
      debugPrint('Folder insert failed: $error\n$trace');
      if (mounted) setState(() => _feedback = 'Folder save failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteFolder(FolderRecord folder) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder and cards?'),
        content: Text(
          'Delete ${folder.name} (ID ${folder.id}) and its ${folder.cardCount} cards?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete folder'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      final affected = await widget.helper.deleteFolder(folder.id);
      if (!mounted) return;
      setState(() {
        if (_selectedFolderId == folder.id) {
          _selectedFolderId = null;
          _formFolderId = null;
          _cards = const [];
          _clearCardForm();
        }
        _feedback = affected == 1
            ? 'Deleted folder ID ${folder.id} (1 row); its cards were removed.'
            : 'Folder ID ${folder.id} was already missing. Refreshing.';
      });
      await _afterWrite();
    } catch (error, trace) {
      debugPrint('Folder delete failed: $error\n$trace');
      if (mounted) setState(() => _feedback = 'Folder delete failed. Refresh and retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearCardForm() {
    _titleController.clear();
    _notesController.clear();
    _imageController.clear();
    _editingCardId = null;
    _titleError = null;
    _suit = suits.first;
  }

  void _editCard(CardRecord card) {
    if (_busy) return;
    setState(() {
      _editingCardId = card.id;
      _titleController.text = card.title;
      _notesController.text = card.notes;
      _imageController.text = card.imageRef ?? '';
      _suit = card.suit;
      _formFolderId = card.folderId;
      _titleError = null;
      _feedback = 'Editing card ID ${card.id}. Cancel makes no database change.';
    });
  }

  Future<void> _saveCard() async {
    if (_busy) return;
    final title = _titleController.text.trim();
    final folderId = _formFolderId;
    setState(() {
      _titleError = title.isEmpty ? 'Enter a card title.' : null;
      _feedback = folderId == null ? 'Choose a folder before saving a card.' : null;
    });
    if (title.isEmpty || folderId == null) return;
    if (!_folders.any((folder) => folder.id == folderId)) {
      setState(() => _feedback = 'That folder no longer exists. Refresh first.');
      return;
    }
    final card = CardRecord(
      id: _editingCardId ?? 0,
      title: title,
      suit: _suit,
      notes: _notesController.text.trim(),
      imageRef: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      folderId: folderId,
    );
    final editingId = _editingCardId;
    setState(() => _busy = true);
    try {
      final result = editingId == null
          ? await widget.helper.insertCard(card)
          : await widget.helper.updateCard(card);
      if (!mounted) return;
      setState(() {
        if (editingId == null || result == 1) {
          _clearCardForm();
          _selectedFolderId = folderId;
        }
        _feedback = editingId == null
            ? 'Added card ID $result.'
            : result == 1
                ? 'Updated card ID $editingId (1 row).'
                : 'Card ID $editingId no longer exists. Refreshing.';
      });
      await _afterWrite();
    } catch (error, trace) {
      debugPrint('Card save failed: $error\n$trace');
      if (mounted) setState(() => _feedback = 'Card save failed. Your input is still here.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCard(CardRecord card) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete ${card.title} (ID ${card.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete card'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      final affected = await widget.helper.deleteCard(card.id);
      if (!mounted) return;
      setState(() {
        if (_editingCardId == card.id) _clearCardForm();
        _feedback = affected == 1
            ? 'Deleted card ID ${card.id} (1 row).'
            : 'Card ID ${card.id} was already missing. Refreshing.';
      });
      await _afterWrite();
    } catch (error, trace) {
      debugPrint('Card delete failed: $error\n$trace');
      if (mounted) setState(() => _feedback = 'Card delete failed. Refresh and retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _suitSymbol(String suit) => switch (suit) {
        'Hearts' => '♥',
        'Diamonds' => '♦',
        'Clubs' => '♣',
        'Spades' => '♠',
        _ => '?',
      };

  Widget _cardImage(CardRecord card) {
    final fallback = CircleAvatar(
      child: Text(_suitSymbol(card.suit),
          semanticsLabel: '${card.suit} image placeholder'),
    );
    final ref = card.imageRef;
    if (ref == null || ref.isEmpty) return fallback;
    if (ref.startsWith('https://') || ref.startsWith('http://')) {
      return Image.network(
        ref,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      );
    }
    if (ref.startsWith('assets/')) {
      return Image.asset(ref, width: 44, height: 44, errorBuilder: (_, _, _) => fallback);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _folders.where((f) => f.id == _selectedFolderId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Refresh catalogue',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Folders', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _folderController,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: 'Folder name',
                    errorText: _folderError,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _addFolder,
                child: const Text('Add folder'),
              ),
            ]),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(_feedback!, key: const Key('catalogue-feedback')),
              ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _readError != null)
              Text(_readError!, key: const Key('catalogue-error')),
            if (!_loading && _readError == null && _folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No folders yet. Create one to organize cards.'),
              ),
            if (!_loading && _readError == null)
              for (final folder in _folders)
                Card(
                  color: folder.id == _selectedFolderId
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: ListTile(
                    title: Text(folder.name),
                    subtitle: Text('ID ${folder.id} · ${folder.cardCount} cards'),
                    onTap: _busy ? null : () => _selectFolder(folder),
                    trailing: IconButton(
                      tooltip: 'Delete folder ID ${folder.id}',
                      onPressed: _busy ? null : () => _deleteFolder(folder),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
            const Divider(height: 28),
            Text(
              selected == null ? 'Choose a folder' : '${selected.name} cards',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_loading && _readError == null && selected != null && _cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('This folder is empty. Add its first card below.'),
              ),
            if (!_loading && _readError == null)
              for (final card in _cards)
                Card(
                  child: ListTile(
                    leading: _cardImage(card),
                    title: Text(card.title),
                    subtitle: Text(
                      'ID ${card.id} · ${card.suit}${card.notes.isEmpty ? '' : ' · ${card.notes}'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit card ID ${card.id}',
                          onPressed: _busy ? null : () => _editCard(card),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Delete card ID ${card.id}',
                          onPressed: _busy ? null : () => _deleteCard(card),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            const Divider(height: 28),
            Text(
              _editingCardId == null ? 'Add card' : 'Edit card ID $_editingCardId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Card title',
                errorText: _titleError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey('suit-$_suit'),
              initialValue: _suit,
              decoration: const InputDecoration(
                labelText: 'Suit',
                border: OutlineInputBorder(),
              ),
              items: suits
                  .map((suit) => DropdownMenuItem(value: suit, child: Text(suit)))
                  .toList(),
              onChanged: _busy ? null : (value) => setState(() => _suit = value ?? suits.first),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: ValueKey('folder-$_formFolderId'),
              initialValue: _formFolderId,
              decoration: const InputDecoration(
                labelText: 'Folder',
                border: OutlineInputBorder(),
              ),
              items: _folders
                  .map((folder) => DropdownMenuItem(
                        value: folder.id,
                        child: Text('${folder.name} (ID ${folder.id})'),
                      ))
                  .toList(),
              onChanged: _busy ? null : (value) => setState(() => _formFolderId = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imageController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Image reference (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _saveCard,
                  child: Text(_editingCardId == null ? 'Add card' : 'Save card ID $_editingCardId'),
                ),
                OutlinedButton(
                  onPressed: _busy || _editingCardId == null
                      ? null
                      : () => setState(() {
                            _clearCardForm();
                            _feedback = 'Edit canceled. No card changed.';
                          }),
                  child: const Text('Cancel card edit'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
