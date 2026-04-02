import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_080/constants/app_constants.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/helpers/log_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();

  Db? _db;
  DbCollection? _collection;

  final String _source = 'mongo_service.dart';

  factory MongoService() => _instance;
  MongoService._internal();

  @visibleForTesting
  static void setTestInstance({Db? db, DbCollection? collection}) {
    _instance._db = db;
    _instance._collection = collection;
  }

  @visibleForTesting
  static void resetTestInstance() {
    _instance._db = null;
    _instance._collection = null;
  }

  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await LogHelper.writeLog(
        'INFO: Koleksi belum siap, mencoba rekoneksi...',
        source: _source,
        level: 3,
      );
      await connect();
    }
    return _collection!;
  }

  Future<void> connect() async {
    try {
      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception('MONGODB_URI tidak ditemukan di .env');

      _db = await Db.create(dbUri);

      await _db!.open().timeout(
        AppConstants.connectionTimeout,
        onTimeout: () {
          throw Exception('Koneksi Timeout. Cek Koneksi Internet.');
        },
      );

      _collection = _db!.collection('logs');

      await LogHelper.writeLog(
        'DATABASE: Terhubung & Koleksi Siap',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Gagal Koneksi - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<List<LogModel>> getLogs(String teamId, String authorId) async {
    try {
      final collection = await _getSafeCollection();

      await LogHelper.writeLog(
        'INFO: Fetching data from Cloud...',
        source: _source,
        level: 3,
      );

      final query = where
          .eq('teamId', teamId)
          .and(where.eq('authorId', authorId).or(where.eq('isPublic', true)));

      final List<Map<String, dynamic>> data = await collection
          .find(query)
          .toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Fetch Failed - $e',
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  Future<void> insertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      await collection.insertOne(log.toMap());

      await LogHelper.writeLog(
        "SUCCESS: Data '${log.title}' Saved to Cloud",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Insert Failed - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> upsertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null) {
        await collection.insertOne(log.toMap());
      } else {
        await collection.replaceOne(
          where.id(ObjectId.fromHexString(log.id!)),
          log.toMap(),
          upsert: true,
        );
      }

      await LogHelper.writeLog(
        "SYNC: Upsert '${log.title}' berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Upsert Failed - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> updateLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null) {
        throw Exception('ID Log tidak ditemukan untuk update');
      }

      await collection.replaceOne(
        where.id(ObjectId.fromHexString(log.id!)),
        log.toMap(),
      );

      await LogHelper.writeLog(
        "DATABASE: Update '${log.title}' Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Update Gagal - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      final collection = await _getSafeCollection();
      await collection.remove(where.id(ObjectId.fromHexString(id)));

      await LogHelper.writeLog(
        'DATABASE: Hapus ID $id Berhasil',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'DATABASE: Hapus Gagal - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      await LogHelper.writeLog(
        'DATABASE: Koneksi ditutup',
        source: _source,
        level: 2,
      );
    }
  }
}
