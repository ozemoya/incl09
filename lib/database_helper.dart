// Extends the instructor's Activity 08 database helper without replacing its
// original guest table or database filename.
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late final Database _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createPartOneTable(db);
        await _createCatalogueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCatalogueTables(db);
      },
    );
  }

  Future<void> _createPartOneTable(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES $foldersTable(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON $cardsTable(folder_id)',
    );
  }

  // Original Activity 08 guest CRUD is retained for migration verification.
  Future<int> insert(Map<String, dynamic> row) => _db.insert(table, row);

  Future<List<Map<String, dynamic>>> queryAllRows() =>
      _db.query(table, orderBy: '$columnId ASC');

  Future<int> queryRowCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;

  Future<int> update(Map<String, dynamic> row) => _db.update(
        table,
        row,
        where: '$columnId = ?',
        whereArgs: [row[columnId]],
      );

  Future<int> delete(int id) =>
      _db.delete(table, where: '$columnId = ?', whereArgs: [id]);

  Future<int> insertFolder(String name) => _db.insert(foldersTable, {
        'name': name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<List<FolderRecord>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM $foldersTable AS f
      LEFT JOIN $cardsTable AS c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.id ASC
    ''');
    return rows.map(FolderRecord.fromMap).toList();
  }

  Future<int> deleteFolder(int id) => _db.delete(
        foldersTable,
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query(
      cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'id ASC',
    );
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) =>
      _db.insert(cardsTable, card.toMap());

  Future<int> updateCard(CardRecord card) => _db.update(
        cardsTable,
        card.toMap(),
        where: 'id = ?',
        whereArgs: [card.id],
      );

  Future<int> deleteCard(int id) =>
      _db.delete(cardsTable, where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>> diagnostics() async => {
        'user_version': Sqflite.firstIntValue(
              await _db.rawQuery('PRAGMA user_version'),
            ) ?? 0,
        'foreign_keys': Sqflite.firstIntValue(
              await _db.rawQuery('PRAGMA foreign_keys'),
            ) ?? 0,
        'foreign_key_list': await _db.rawQuery('PRAGMA foreign_key_list(cards)'),
        'index_list': await _db.rawQuery('PRAGMA index_list(cards)'),
        'guest_rows': await queryAllRows(),
      };
}
