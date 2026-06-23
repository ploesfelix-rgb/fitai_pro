// lib/data/database.dart
//
// Modulo 3: persistencia local cifrada (SQLite + SQLCipher via Drift).
// Solo numeros y texto plano. Nunca imagenes. wipeAll() para logout atomico.

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart'; // generado: dart run build_runner build

class NutritionDays extends Table {
  TextColumn get dateKey => text()();
  RealColumn get kcal => real().withDefault(const Constant(0))();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  RealColumn get targetKcal => real().withDefault(const Constant(0))();
  RealColumn get targetProtein => real().withDefault(const Constant(0))();
  BoolColumn get logged => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {dateKey};
}

class BodyMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateIso => text()();
  RealColumn get bodyFat => real()();
  RealColumn get chestRatio => real()();
  RealColumn get abAdipose => real()();
  RealColumn get scapularWidth => real()();
  RealColumn get deltRelief => real()();
  RealColumn get latSpread => real()();
  RealColumn get symmetry => real()();
}

class LiftLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get exercise => text()();
  IntColumn get session => integer()();
  RealColumn get kg => real()();
  IntColumn get reps => integer()();
  BoolColumn get hitTop => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [NutritionDays, BodyMetrics, LiftLogs])
class FitAiDb extends _$FitAiDb {
  FitAiDb(QueryExecutor e) : super(e);
  @override
  int get schemaVersion => 1;

  /// Borrado atomico: vacia todas las tablas en una transaccion.
  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(nutritionDays).go();
      await delete(bodyMetrics).go();
      await delete(liftLogs).go();
    });
  }
}

const _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _keyName = 'fitai_db_key';

LazyDatabase openEncrypted() {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fitai_enc.db'));
    var key = await _secure.read(key: _keyName);
    if (key == null) {
      key = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padRight(64, 'a').substring(0, 64);
      await _secure.write(key: _keyName, value: key);
    }
    return NativeDatabase(file, setup: (raw) {
      raw.execute("PRAGMA key = '$key';");
      raw.execute("PRAGMA cipher_page_size = 4096;");
    });
  });
}
