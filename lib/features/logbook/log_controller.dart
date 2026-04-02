import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/helpers/log_helper.dart';
import 'package:logbook_app_080/services/access_control_service.dart';
import 'package:logbook_app_080/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' hide Box;

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<List<LogModel>> filteredLogs = ValueNotifier([]);

  final String username;
  final String authorId;
  final String teamId;
  final String userRole;

  final Box<LogModel> _box;
  final MongoService _mongoService;

  LogController({
    required this.username,
    required this.authorId,
    required this.teamId,
    required this.userRole,
    Box<LogModel>? box,
    MongoService? mongoService,
  })  : _box = box ?? Hive.box<LogModel>('offline_logs'),
        _mongoService = mongoService ?? MongoService() {
    logsNotifier.addListener(() => filteredLogs.value = getVisibleLogs());
  }

  void dispose() {
    logsNotifier.dispose();
    filteredLogs.dispose();
  }

  List<LogModel> get logs => logsNotifier.value;

  List<LogModel> getVisibleLogs() {
    return logsNotifier.value.where((log) {
      final bool isOwner = log.authorId == authorId;
      return AccessControlService.canView(
        isOwner: isOwner,
        isPublic: log.isPublic,
      );
    }).toList();
  }

  Future<void> addLog(
    String title,
    String desc, {
    String category = 'Pribadi',
    String? authorId,
    String? teamId,
    bool isPublic = false,
  }) async {
    final newLog = LogModel(
      id: ObjectId().oid,
      username: username,
      title: title,
      description: desc,
      timestamp: DateTime.now().toString(),
      category: category,
      authorId: authorId ?? this.authorId,
      teamId: teamId ?? this.teamId,
      isPublic: isPublic,
    );

    await _box.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];
    // filteredLogs.value = [...logsNotifier.value, newLog];

    try {
      await _mongoService.insertLog(newLog);

      await LogHelper.writeLog(
        "SUCCESS: Tambah data '${newLog.title}'",
        source: 'log_controller.dart',
      );
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Gagal sinkronisasi Add - $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  Future<void> updateLog({
    required LogModel targetLog,
    required String title,
    required String desc,
    required String category,
    required bool isPublic,
  }) async {
    final realIndex = logsNotifier.value.indexWhere(
      (log) =>
          log.timestamp == targetLog.timestamp &&
          log.authorId == targetLog.authorId &&
          log.title == targetLog.title,
    );
    if (realIndex == -1) return;

    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[realIndex];

    final bool isOwner = oldLog.authorId == authorId;
    if (!AccessControlService.canPerform(
      userRole,
      AccessControlService.actionUpdate,
      isOwner: isOwner,
    )) {
      await LogHelper.writeLog(
        'SECURITY: Unauthorized update attempt by $authorId',
        source: 'log_controller.dart',
        level: 1,
      );
      return;
    }

    final updatedLog = LogModel(
      id: oldLog.id,
      username: username,
      title: title,
      description: desc,
      timestamp: DateTime.now().toString(),
      category: category,
      authorId: authorId,
      teamId: teamId,
      isPublic: isPublic,
    );

    await _box.putAt(realIndex, updatedLog);
    currentLogs[realIndex] = updatedLog;
    logsNotifier.value = currentLogs;
    // filteredLogs.value = currentLogs;

    try {
      await _mongoService.updateLog(updatedLog);

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: 'log_controller.dart',
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Gagal sinkronisasi Update - $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  Future<void> removeLog(LogModel targetLog) async {
    final realIndex = logsNotifier.value.indexWhere(
      (log) =>
          log.timestamp == targetLog.timestamp &&
          log.authorId == targetLog.authorId &&
          log.title == targetLog.title,
    );
    if (realIndex == -1) return;

    final currentLogs = List<LogModel>.from(logsNotifier.value);

    final bool isOwner = targetLog.authorId == authorId;
    if (!AccessControlService.canPerform(
      userRole,
      AccessControlService.actionDelete,
      isOwner: isOwner,
    )) {
      await LogHelper.writeLog(
        'SECURITY: Unauthorized delete attempt by $authorId',
        source: 'log_controller.dart',
        level: 1,
      );
      return;
    }

    await _box.deleteAt(realIndex);
    currentLogs.removeAt(realIndex);
    logsNotifier.value = currentLogs;
    // filteredLogs.value = currentLogs;

    try {
      if (targetLog.id == null) {
        throw Exception(
          'ID Log tidak ditemukan, tidak bisa menghapus di Cloud.',
        );
      }

      await _mongoService.deleteLog(targetLog.id!);

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: 'log_controller.dart',
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'ERROR: Gagal sinkronisasi Hapus - $e',
        source: 'log_controller.dart',
        level: 1,
      );
    }
  }

  void searchLog(String query) {
    if (query.isEmpty) {
      filteredLogs.value = getVisibleLogs();
    } else {
      filteredLogs.value = getVisibleLogs().where((log) {
        bool searchTitle = log.title.toLowerCase().contains(
          query.toLowerCase(),
        );
        bool searchDesc = log.description.toLowerCase().contains(
          query.toLowerCase(),
        );
        return searchTitle || searchDesc;
      }).toList();
    }
  }

  void loadOfflineLogs() {
    final logs = _box.values.toList();
    logsNotifier.value = logs;
    // filteredLogs.value = logs;
  }

  Future<void> loadLogs() async {
    loadOfflineLogs();

    try {
      final cloudData = await _mongoService.getLogs(teamId, authorId);

      await _box.clear();
      await _box.addAll(cloudData);

      logsNotifier.value = cloudData;
      // filteredLogs.value = cloudData;

      await LogHelper.writeLog(
        'SYNC: Data berhasil diperbarui dari MongoDB',
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'OFFLINE: Menggunakan data cache lokal',
        level: 2,
      );
    }
  }
}
