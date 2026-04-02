import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/services/mongo_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MockDb extends Mock implements Db {}

class MockDbCollection extends Mock implements DbCollection {}

class MockWriteResult extends Mock implements WriteResult {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('Module 4 - MongoService.insertLog() (Save Data to Cloud)', () {
    late MockDb mockDb;
    late MockDbCollection mockCollection;
    late MongoService service;
    late LogModel testLog;

    setUp(() {
      // (1) setup (arrange, build)
      dotenv.loadFromString(envString: 'LOG_LEVEL=2\nLOG_MUTE=');

      mockDb = MockDb();
      mockCollection = MockDbCollection();

      when(() => mockDb.isConnected).thenReturn(true);
      MongoService.setTestInstance(db: mockDb, collection: mockCollection);

      service = MongoService();

      testLog = LogModel(
        id: ObjectId().oid,
        username: 'test_user',
        title: 'Test Log',
        description: 'Deskripsi test log',
        timestamp: DateTime.now().toString(),
        category: 'Pribadi',
        authorId: 'test_001',
        teamId: 'TEAM_01',
      );
    });

    tearDown(() {
      MongoService.resetTestInstance();
    });

    test('TC01: insertLog berhasil menyimpan data ke collection', () async {
      // (1) setup (arrange, build)
      when(
        () => mockCollection.insertOne(any()),
      ).thenAnswer((_) async => MockWriteResult());

      // (2) exercise (act, operate)
      await service.insertLog(testLog);

      // (3) verify (assert, check)
      final actual = verify(
        () => mockCollection.insertOne(captureAny()),
      ).callCount;
      const expected = 1;
      expect(
        actual,
        expected,
        reason: 'Expected insertOne dipanggil $expected kali, actual $actual',
      );
    });

    test('TC02: insertLog melempar exception saat collection error', () async {
      // (1) setup (arrange, build)
      when(
        () => mockCollection.insertOne(any()),
      ).thenThrow(Exception('DB Write Error'));

      // (2) exercise (act, operate) & (3) verify (assert, check)
      expect(
        () => service.insertLog(testLog),
        throwsA(isA<Exception>()),
        reason: 'Expected exception di-rethrow ke pemanggil',
      );
    });

    test(
      'TC03: insertLog mengirim data Map yang sesuai dengan LogModel',
      () async {
        // (1) setup (arrange, build)
        Map<String, dynamic>? capturedData;
        when(() => mockCollection.insertOne(any())).thenAnswer((
          invocation,
        ) async {
          capturedData =
              invocation.positionalArguments[0] as Map<String, dynamic>;
          return MockWriteResult();
        });

        // (2) exercise (act, operate)
        await service.insertLog(testLog);

        // (3) verify (assert, check)
        expect(
          capturedData,
          isNotNull,
          reason: 'Data harus dikirim ke insertOne',
        );

        final actualTitle = capturedData!['title'];
        final expectedTitle = testLog.title;
        expect(
          actualTitle,
          expectedTitle,
          reason: 'Expected title "$expectedTitle" but got "$actualTitle"',
        );

        final actualAuthor = capturedData!['authorId'];
        final expectedAuthor = testLog.authorId;
        expect(
          actualAuthor,
          expectedAuthor,
          reason: 'Expected authorId "$expectedAuthor" but got "$actualAuthor"',
        );
      },
    );
  });
}
