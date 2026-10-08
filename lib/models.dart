class FolderRecord {
  const FolderRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  final int id;
  final String name;
  final String createdAt;
  final int cardCount;

  factory FolderRecord.fromMap(Map<String, Object?> row) => FolderRecord(
        id: row['id'] as int,
        name: row['name'] as String,
        createdAt: row['created_at'] as String,
        cardCount: (row['card_count'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };
}

class CardRecord {
  const CardRecord({
    required this.id,
    required this.title,
    required this.suit,
    required this.folderId,
    this.notes = '',
    this.imageRef,
  });

  final int id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  factory CardRecord.fromMap(Map<String, Object?> row) => CardRecord(
        id: row['id'] as int,
        title: row['title'] as String,
        suit: row['suit'] as String,
        notes: row['notes'] as String? ?? '',
        imageRef: row['image_ref'] as String?,
        folderId: row['folder_id'] as int,
      );

  Map<String, Object?> toMap() => {
        if (id > 0) 'id': id,
        'title': title,
        'suit': suit,
        'notes': notes,
        'image_ref': imageRef,
        'folder_id': folderId,
      };
}
