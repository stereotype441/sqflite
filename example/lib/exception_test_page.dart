import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sql.dart';

import 'test_page.dart';

class ExceptionTestPage extends TestPage {
  ExceptionTestPage() : super("Exception tests") {
    test("Transaction failed", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("transaction_failed.db");
      Database db = await openDatabase(path);

      await db.execute("CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)");

      // insert then fails to make sure the transaction is cancelled
      bool hasFailed = false;
      try {
        await db.transaction((txn) async {
          await txn.rawInsert("INSERT INTO Test (name) VALUES (?)", ["item"]);
          int afterCount = Sqflite
              .firstIntValue(await txn.rawQuery("SELECT COUNT(*) FROM Test"));
          expect(afterCount, 1);

          hasFailed = true;
          // this failure should cancel the insertion before
          await txn.execute("DUMMY CALL");
          hasFailed = false;
        });
      } on DatabaseException catch (e) {
        // iOS: native_error: PlatformException(sqlite_error, Error Domain=FMDatabase Code=1 "near "DUMMY": syntax error" UserInfo={NSLocalizedDescription=near "DUMMY": syntax error}, null)
        print("native_error: $e");
      }
      verify(hasFailed);

      int afterCount =
          Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM Test"));
      expect(afterCount, 0);

      await db.close();
    });

    test("Batch failed", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("batch_failed.db");
      Database db = await openDatabase(path);

      await db.execute("CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT)");

      var batch = db.batch();
      batch.rawInsert("INSERT INTO Test (name) VALUES (?)", ["item"]);
      batch.execute("DUMMY CALL");

      bool hasFailed = true;
      try {
        await batch.apply();
        hasFailed = false;
      } on DatabaseException catch (e) {
        print("native_error: $e");
      }

      verify(hasFailed);

      int afterCount =
          Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM Test"));
      expect(afterCount, 0);

      await db.close();
    });

    test("Sqlite Exception", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("exception.db");
      Database db = await openDatabase(path);

      // Query
      try {
        await db.rawQuery("SELECT COUNT(*) FROM Test");
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isNoSuchTableError("Test"));
        // Error Domain=FMDatabase Code=1 "no such table: Test" UserInfo={NSLocalizedDescription=no such table: Test})
      }

      // Catch without using on DatabaseException
      try {
        await db.rawQuery("malformed query");
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        //verify(e.toString().contains("sql 'malformed query' args"));
        // devPrint(e);
      }

      try {
        await db.rawQuery("malformed query with args ?", [1]);
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        print(e);
        verify(e
            .toString()
            .contains("sql 'malformed query with args ?' args [1]"));
      }

      try {
        await db.execute("DUMMY");
        fail(); // should fail before
      } on Exception catch (e) {
        //verify(e.isSyntaxError());
        print(e);
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      try {
        await db.rawInsert("DUMMY");
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      try {
        await db.rawUpdate("DUMMY");
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      await db.close();
    });

    test("Sqlite constraint Exception", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("constraint_exception.db");
      Database db =
          await openDatabase(path, version: 1, onCreate: (db, version) {
        db.execute("CREATE TABLE Test (name TEXT UNIQUE)");
      });
      await db.insert("Test", {"name": "test1"});

      try {
        await db.insert("Test", {"name": "test1"});
      } on DatabaseException catch (e) {
        // iOS: Error Domain=FMDatabase Code=19 "UNIQUE constraint failed: Test.name" UserInfo={NSLocalizedDescription=UNIQUE constraint failed: Test.name}) s
        // Android: UNIQUE constraint failed: Test.name (code 2067))
        print(e);
        verify(e.isUniqueConstraintError());
        verify(e.isUniqueConstraintError("Test.name"));
      }

      await db.close();
    });

    test("Sqlite constraint primary key Exception", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("constraint_primary_key_exception.db");
      Database db =
      await openDatabase(path, version: 1, onCreate: (db, version) {
        db.execute("CREATE TABLE Test (name TEXT PRIMARY KEY)");
      });
      await db.insert("Test", {"name": "test1"});

      try {
        await db.insert("Test", {"name": "test1"});
      } on DatabaseException catch (e) {
        // iOS: Error Domain=FMDatabase Code=19 "UNIQUE constraint failed: Test.name" UserInfo={NSLocalizedDescription=UNIQUE constraint failed: Test.name}) s
        // Android: UNIQUE constraint failed: Test.name (code 2067))
        print(e);
        verify(e.isUniqueConstraintError());
        verify(e.isUniqueConstraintError("Test.name"));
      }

      await db.close();
    });

    test("Sqlite batch Exception", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("batch_exception.db");
      Database db = await openDatabase(path);

      // Query
      try {
        var batch = db.batch();
        batch.rawQuery("SELECT COUNT(*) FROM Test");
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isNoSuchTableError("Test"));
      }

      // Catch without using on DatabaseException
      try {
        var batch = db.batch();
        batch.rawQuery("malformed query");
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        print(e);
        verify(e.toString().contains("sql 'malformed query'"));
      }

      try {
        var batch = db.batch();
        batch.rawQuery("malformed query with args ?", [1]);
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        print(e);
        verify(e
            .toString()
            .contains("sql 'malformed query with args ?' args [1]"));
      }

      try {
        var batch = db.batch();
        batch.execute("DUMMY");
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        // devPrint(e);
        // iOS Error Domain=FMDatabase Code=1 "near "DUMMY": syntax error" UserInfo={NSLocalizedDescription=near "DUMMY": syntax error})
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      try {
        var batch = db.batch();
        batch.rawInsert("DUMMY");
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      try {
        var batch = db.batch();
        batch.rawUpdate("DUMMY");
        await batch.commit();
        fail(); // should fail before
      } on DatabaseException catch (e) {
        verify(e.isSyntaxError());
        verify(e.toString().contains("sql 'DUMMY'"));
      }

      await db.close();
    });

    test("Open onDowngrade fail", () async {
      String path = await initDeleteDb("open_on_downgrade_fail.db");
      Database database = await openDatabase(path, version: 2,
          onCreate: (Database db, int version) async {
        await db.execute("CREATE TABLE Test(id INTEGER PRIMARY KEY)");
      });
      await database.close();

      // currently this is crashing...
      // should fail going back in versions
      try {
        database = await openDatabase(path,
            version: 1, onDowngrade: onDatabaseVersionChangeError);
        verify(false);
      } catch (e) {
        print(e);
      }

      // should work
      database = await openDatabase(path,
          version: 2, onDowngrade: onDatabaseVersionChangeError);
      print(database);
      await database.close();
    });

    test("Access after close", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("access_after_close.db");
      Database database = await openDatabase(path, version: 3,
          onCreate: (Database db, int version) async {
        await db.execute("CREATE TABLE Test(id INTEGER PRIMARY KEY)");
      });
      await database.close();
      try {
        await database.getVersion();
        verify(false);
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isDatabaseClosedError());
      }

      try {
        await database.setVersion(1);
        fail();
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isDatabaseClosedError());
      }
    });

    test("Non escaping fields", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("non_escaping_fields.db");
      Database db = await openDatabase(path);

      String table = "table";
      try {
        await db.execute("CREATE TABLE $table (group INTEGER)");
        fail("should fail");
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isSyntaxError());
      }
      try {
        await db.execute("INSERT INTO $table (group) VALUES (1)");
        fail("should fail");
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isSyntaxError());
      }
      try {
        await db.rawQuery("SELECT * FROM $table ORDER BY group DESC");
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isSyntaxError());
      }

      try {
        await db.rawQuery("DELETE FROM $table");
      } on DatabaseException catch (e) {
        print(e);
        verify(e.isSyntaxError());
      }

      // Build our escape list from all the sqlite keywords
      List<String> toExclude = [];
      for (String name in allEscapeNames) {
        try {
          await db.execute("CREATE TABLE $name (value INTEGER)");
        } on DatabaseException catch (e) {
          await db.execute("CREATE TABLE ${escapeName(name)} (value INTEGER)");

          verify(e.isSyntaxError());
          toExclude.add(name);
        }
      }
      print(json.encode(toExclude));

      await db.close();
    });

    test("Bind no argument (no iOS)", () async {
      if (!Platform.isIOS) {
        // await Sqflite.devSetDebugModeOn(true);
        String path = await initDeleteDb("bind_no_arg_failed.db");
        Database db = await openDatabase(path);

        await db.execute("CREATE TABLE Test (name TEXT)");

        await db.rawInsert("INSERT INTO Test (name) VALUES (\"?\")", []);

        await db.rawQuery("SELECT * FROM Test WHERE name = ?", []);

        await db.rawDelete("DELETE FROM Test WHERE name = ?", []);

        await db.close();
      }
    });

    test("crash ios (no iOS)", () async {
      // This crashes natively on iOS...can't catch it yet
      if (!Platform.isIOS) {
        //if (true) {
        // await Sqflite.devSetDebugModeOn(true);
        String path = await initDeleteDb("bind_no_arg_failed.db");
        Database db = await openDatabase(path);

        await db.execute("CREATE TABLE Test (name TEXT)");

        await db.rawInsert("INSERT INTO Test (name) VALUES (\"?\")", []);

        await db.rawQuery("SELECT * FROM Test WHERE name = ?", []);

        await db.close();
      }
    });

    test("Bind null argument", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("bind_null_failed.db");
      Database db = await openDatabase(path);

      await db.execute("CREATE TABLE Test (name TEXT)");

      //await db.rawInsert("INSERT INTO Test (name) VALUES (\"?\")", [null]);
      try {
        await db.rawInsert("INSERT INTO Test (name) VALUES (?)", [null]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'INSERT"), true);
      }

      try {
        await db.rawQuery("SELECT * FROM Test WHERE name = ?", [null]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'SELECT * FROM Test"), true);
      }

      try {
        await db.rawDelete("DELETE FROM Test WHERE name = ?", [null]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'DELETE FROM Test"), true);
      }

      await db.close();
    });

    test("Bind no parameter", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await initDeleteDb("bind_no_parameter_failed.db");
      Database db = await openDatabase(path);

      await db.execute("CREATE TABLE Test (name TEXT)");

      try {
        await db.rawInsert(
            "INSERT INTO Test (name) VALUES (\"value\")", ["value2"]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'INSERT INTO Test"), true);
      }

      try {
        await db
            .rawQuery("SELECT * FROM Test WHERE name = \"value\"", ["value2"]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'SELECT * FROM Test"), true);
      }

      try {
        await db
            .rawDelete("DELETE FROM Test WHERE name = \"value\"", ["value2"]);
      } on DatabaseException catch (e) {
        print("ERR: $e");
        expect(e.toString().contains("sql 'DELETE FROM Test"), true);
      }

      await db.close();
    });
  }
}

var escapeNames = [
  "add",
  "all",
  "alter",
  "and",
  "as",
  "autoincrement",
  "between",
  "case",
  "check",
  "collate",
  "commit",
  "constraint",
  "create",
  "default",
  "deferrable",
  "delete",
  "distinct",
  "drop",
  "else",
  "escape",
  "except",
  "exists",
  "foreign",
  "from",
  "group",
  "having",
  "if",
  "in",
  "index",
  "insert",
  "intersect",
  "into",
  "is",
  "isnull",
  "join",
  "limit",
  "not",
  "notnull",
  "null",
  "on",
  "or",
  "order",
  "primary",
  "references",
  "select",
  "set",
  "table",
  "then",
  "to",
  "transaction",
  "union",
  "unique",
  "update",
  "using",
  "values",
  "when",
  "where"
];

var allEscapeNames = [
  "abort",
  "action",
  "add",
  "after",
  "all",
  "alter",
  "analyze",
  "and",
  "as",
  "asc",
  "attach",
  "autoincrement",
  "before",
  "begin",
  "between",
  "by",
  "cascade",
  "case",
  "cast",
  "check",
  "collate",
  "column",
  "commit",
  "conflict",
  "constraint",
  "create",
  "cross",
  "current_date",
  "current_time",
  "current_timestamp",
  "database",
  "default",
  "deferrable",
  "deferred",
  "delete",
  "desc",
  "detach",
  "distinct",
  "drop",
  "each",
  "else",
  "end",
  "escape",
  "except",
  "exclusive",
  "exists",
  "explain",
  "fail",
  "for",
  "foreign",
  "from",
  "full",
  "glob",
  "group",
  "having",
  "if",
  "ignore",
  "immediate",
  "in",
  "index",
  "indexed",
  "initially",
  "inner",
  "insert",
  "instead",
  "intersect",
  "into",
  "is",
  "isnull",
  "join",
  "key",
  "left",
  "like",
  "limit",
  "match",
  "natural",
  "no",
  "not",
  "notnull",
  "null",
  "of",
  "offset",
  "on",
  "or",
  "order",
  "outer",
  "plan",
  "pragma",
  "primary",
  "query",
  "raise",
  "recursive",
  "references",
  "regexp",
  "reindex",
  "release",
  "rename",
  "replace",
  "restrict",
  "right",
  "rollback",
  "row",
  "savepoint",
  "select",
  "set",
  "table",
  "temp",
  "temporary",
  "then",
  "to",
  "transaction",
  "trigger",
  "union",
  "unique",
  "update",
  "using",
  "vacuum",
  "values",
  "view",
  "virtual",
  "when",
  "where",
  "with",
  "without"
];
