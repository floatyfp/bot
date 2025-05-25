import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import '../models/permission_level.dart';
import 'package:nyxx/nyxx.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  static Database? _database;

  factory PermissionService() => _instance;

  PermissionService._internal() {
    _initDatabase();
  }

  Database get database {
    _database ??= _initDatabase();
    return _database!;
  }

  Database _initDatabase() {
    final dir = Directory('data');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/permissions.db';
    final db = sqlite3.open(path);

    // Enable foreign keys
    db.execute('PRAGMA foreign_keys = ON');

    _createDb(db);

    // Initialize owner from environment variables
    _initializeOwner(db);

    return db;
  }

  void _createDb(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS user_permissions(
        user_id TEXT PRIMARY KEY,
        level TEXT NOT NULL,
        username TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  void setUserPermission(UserPermission permission) {
    final db = database;
    final stmt = db.prepare('''
      INSERT OR REPLACE INTO user_permissions 
      (user_id, level, username, created_at)
      VALUES (?, ?, ?, ?)
    ''');

    stmt.execute([
      permission.userId,
      permission.level.name,
      permission.username,
      DateTime.now().millisecondsSinceEpoch,
    ]);

    stmt.dispose();
  }

  void removeUserPermission(String userId) {
    final db = database;
    final stmt = db.prepare('DELETE FROM user_permissions WHERE user_id = ?');
    stmt.execute([userId]);
    stmt.dispose();
  }

  PermissionLevel getUserPermissionLevel(String userId) {
    final db = database;
    final result = db.select(
        'SELECT level FROM user_permissions WHERE user_id = ?', [userId]);

    if (result.isEmpty) return PermissionLevel.user;
    return PermissionLevelExtension.fromString(result.first['level'] as String);
  }

  List<UserPermission> getAllPermissions() {
    final db = database;
    final result = db.select('SELECT * FROM user_permissions');
    return result
        .map((e) => UserPermission.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  bool hasPermission(PermissionLevel requiredLevel, User user) {
    final userId = user.id.toString();
    final username = user.username;

    // Always update the username if it has changed
    updateUsernameIfNeeded(userId, username);

    if (requiredLevel == PermissionLevel.user) return true;

    // Check if user is the owner from environment variables
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final ownerId = env['BOT_OWNER_ID'];
    if (ownerId == userId) {
      return true; // Owner has all permissions
    }

    final userLevel = getUserPermissionLevel(userId);
    return userLevel.index >= requiredLevel.index;
  }

  void updateUsernameIfNeeded(String userId, String newUsername) {
    final db = database;
    final result = db.select(
      'SELECT username FROM user_permissions WHERE user_id = ?',
      [userId],
    );

    if (result.isNotEmpty) {
      final currentUsername = result.first['username'] as String?;
      if (currentUsername != newUsername) {
        final stmt = db.prepare(
          'UPDATE user_permissions SET username = ? WHERE user_id = ?',
        );
        stmt.execute([newUsername, userId]);
        stmt.dispose();
      }
    }
  }

  void _initializeOwner(Database db) {
    final env = DotEnv(includePlatformEnvironment: true)..load();
    final ownerId = env['BOT_OWNER_ID'];

    if (ownerId == null || ownerId.isEmpty) {
      print('Warning: BOT_OWNER_ID not set in .env file');
      return;
    }

    // Check if owner already exists in the database
    final result = db.select(
      'SELECT * FROM user_permissions WHERE user_id = ?',
      [ownerId],
    );

    if (result.isEmpty) {
      // Add owner to the database
      final stmt = db.prepare('''
        INSERT INTO user_permissions 
        (user_id, level, username, created_at)
        VALUES (?, ?, ?, ?)
      ''');

      stmt.execute([
        ownerId,
        PermissionLevel.owner.name,
        'Owner', // Username will be updated on first command use
        DateTime.now().millisecondsSinceEpoch,
      ]);

      stmt.dispose();
      print('Added owner with ID: $ownerId');
    }
  }

  void close() {
    _database?.dispose();
    _database = null;
  }
}
