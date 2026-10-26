import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class QueueItem {
  final String id;
  final String type; // 'faces' | 'recognize'
  final String endpoint;
  final Map<String, dynamic> payload;
  final int attempts;
  final int nextAttemptAt; // epoch ms
  final String status; // 'pending' | 'processing' | 'done' | 'failed'
  final int createdAt; // epoch ms

  QueueItem({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.payload,
    this.attempts = 0,
    required this.nextAttemptAt,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'endpoint': endpoint,
      'payload': jsonEncode(payload),
      'attempts': attempts,
      'next_attempt_at': nextAttemptAt,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'] as String,
      type: map['type'] as String,
      endpoint: map['endpoint'] as String? ?? '',
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      attempts: (map['attempts'] as num).toInt(),
      nextAttemptAt: (map['next_attempt_at'] as num).toInt(),
      status: map['status'] as String,
      createdAt: (map['created_at'] as num).toInt(),
    );
  }

  QueueItem copyWith({
    int? attempts,
    int? nextAttemptAt,
    String? status,
  }) {
    return QueueItem(
      id: id,
      type: type,
      endpoint: endpoint,
      payload: payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class QueueDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'upload_queue.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE upload_queue (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            payload TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> enqueue(QueueItem item) async {
    final db = await database;
    await db.insert(
      'upload_queue',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QueueItem>> getPendingItems({int? nowMs}) async {
    final db = await database;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final results = await db.query(
      'upload_queue',
      where: 'status = ? AND next_attempt_at <= ?',
      whereArgs: ['pending', now],
      orderBy: 'created_at ASC',
    );

    return results.map((m) => QueueItem.fromMap(m)).toList();
  }

  Future<void> updateItem(QueueItem item) async {
    final db = await database;
    await db.update(
      'upload_queue',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<QueueItem?> getItem(String id) async {
    final db = await database;
    final results = await db.query(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return QueueItem.fromMap(results.first);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<QueueItem>> getAllItems() async {
    final db = await database;
    final results = await db.query(
      'upload_queue',
      orderBy: 'created_at DESC',
    );
    return results.map((m) => QueueItem.fromMap(m)).toList();
  }
}
