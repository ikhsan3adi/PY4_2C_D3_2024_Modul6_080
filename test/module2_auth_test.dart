import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_080/features/auth/login_controller.dart';

void main() {
  group('Module 2 - LoginController', () {
    late LoginController controller;

    setUp(() {
      controller = LoginController();
    });

    test('TC01: Login dengan username dan password valid (Path True)', () {
      final actual = controller.login('admin', '123');
      const expected = true;
      expect(actual, expected);
    });

    test('TC02: Login dengan password salah (Path False)', () {
      final actual = controller.login('admin', 'wrong_pass');
      const expected = false;
      expect(actual, expected);
    });

    test('TC03: 3x gagal berturut-turut akun ter-lockout', () {
      controller.login('admin', 'wrong1');
      controller.login('admin', 'wrong2');
      controller.login('admin', 'wrong3');
      
      final actual = controller.isLocked.value;
      const expected = true;
      expect(actual, expected);
    });
  });
}
