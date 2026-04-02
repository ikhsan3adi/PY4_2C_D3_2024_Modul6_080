import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:logbook_app_080/features/logbook/log_controller.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/services/mongo_service.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<LogModel> {}

class MockMongoService extends Mock implements MongoService {}

void main() {
  setUpAll(() {
    registerFallbackValue(LogModel(
      username: '',
      title: '',
      description: '',
      timestamp: '',
      authorId: '',
      teamId: '',
    ));
  });

  group('Module 3 - LogController.addLog() (Save Data to Disk)', () {
    late LogController controller;
    late MockBox mockBox;
    late MockMongoService mockMongo;

    const username = 'test_user';
    const authorId = 'test_001';
    const teamId = 'TEAM_01';
    const userRole = 'Anggota';

    setUp(() {
      // (1) setup (arrange, build)
      dotenv.loadFromString(envString: 'LOG_LEVEL=2\nLOG_MUTE=');

      mockBox = MockBox();
      mockMongo = MockMongoService();

      when(() => mockBox.add(any())).thenAnswer((_) async => 0);
      when(
        () => mockMongo.insertLog(any()),
      ).thenAnswer((_) async => Future.value());

      controller = LogController(
        username: username,
        authorId: authorId,
        teamId: teamId,
        userRole: userRole,
        box: mockBox,
        mongoService: mockMongo,
      );
    });

    test(
      'TC01: addLog dengan default authorId menyimpan ke Hive box',
      () async {
        // (2) exercise (act, operate)
        await controller.addLog('Log Pertama', 'Deskripsi log pertama');

        // (3) verify (assert, check)
        final actual = verify(() => mockBox.add(captureAny())).captured.single;
        final expected = authorId;
        expect(
          (actual as LogModel).authorId,
          expected,
          reason: 'Expected authorId $expected but got ${actual.authorId}',
        );
      },
    );

    test(
      'TC02: addLog dengan custom authorId menggunakan nilai custom',
      () async {
        // (1) setup (arrange, build)
        const customAuthor = 'custom_author_099';

        // (2) exercise (act, operate)
        await controller.addLog(
          'Log Custom',
          'Deskripsi custom',
          authorId: customAuthor,
        );

        // (3) verify (assert, check)
        final actual = verify(() => mockBox.add(captureAny())).captured.single;
        final expected = customAuthor;
        expect(
          (actual as LogModel).authorId,
          expected,
          reason: 'Expected authorId $expected but got ${actual.authorId}',
        );
      },
    );

    test(
      'TC03: addLog memperbarui logsNotifier dengan data yang benar',
      () async {
        // (2) exercise (act, operate)
        await controller.addLog(
          'Log Notifier Test',
          'Deskripsi notifier',
          category: 'Tim',
        );

        // (3) verify (assert, check)
        final actualLength = controller.logsNotifier.value.length;
        const expectedLength = 1;
        expect(
          actualLength,
          expectedLength,
          reason: 'Expected $expectedLength item but got $actualLength',
        );

        final actualTitle = controller.logsNotifier.value.first.title;
        const expectedTitle = 'Log Notifier Test';
        expect(
          actualTitle,
          expectedTitle,
          reason: 'Expected title "$expectedTitle" but got "$actualTitle"',
        );
      },
    );
  });
}
