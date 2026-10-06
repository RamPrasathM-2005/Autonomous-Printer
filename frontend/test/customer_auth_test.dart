import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/customer_auth_service.dart';
import 'package:frontend/services/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> tokenResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'user': {
    'id': 1,
    'email': '24104048@nec.edu.in',
    'full_name': 'Test Student',
    'roll_number': '24104048',
    'department': 'CSE',
    'role': 'USER',
    'is_active': true,
    'created_at': '2026-10-06T00:00:00Z',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    for (final key in [
      'student_auth_access_token',
      'student_auth_refresh_token',
      'student_auth_user_profile',
    ]) {
      clearSessionValue(key);
    }
    await SessionStore.init();
  });

  test(
    'Email signup, verification and login never populate phone with email',
    () async {
      final requests = <http.Request>[];
      final auth = CustomerAuthService.withClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/verify-otp')
                  ? {'valid': true}
                  : tokenResponse(),
            ),
            200,
          );
        }),
      );
      await auth.verifyOtp(' 24104048@NEC.EDU.IN ', '123456');
      await auth.studentSignup(
        fullName: 'Test Student',
        rollNumber: '24104048',
        email: ' 24104048@NEC.EDU.IN ',
        department: 'CSE',
        otp: '123456',
      );
      await auth.studentLogin(email: '24104048@nec.edu.in', otp: '123456');
      for (final request in requests) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['email'], '24104048@nec.edu.in');
        expect(payload.containsKey('phone'), isFalse);
      }
      expect(auth.isLoggedIn, isTrue);
      expect(
        readSessionValue('student_auth_refresh_token'),
        'test-refresh-token',
      );
    },
  );

  test('An explicitly provided phone is preserved', () async {
    final auth = CustomerAuthService.withClient(
      MockClient((request) async {
        expect(jsonDecode(request.body)['phone'], '9876543210');
        return http.Response(jsonEncode(tokenResponse()), 201);
      }),
    );
    await auth.studentSignup(
      fullName: 'Test Student',
      rollNumber: '24104048',
      email: '24104048@nec.edu.in',
      department: 'CSE',
      otp: '123456',
      phone: ' 9876543210 ',
    );
  });

  test(
    'Logout clears local authentication before the network completes',
    () async {
      final pending = Completer<http.Response>();
      final auth = CustomerAuthService.withClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/logout')) return pending.future;
          return http.Response(jsonEncode(tokenResponse()), 200);
        }),
      );
      await auth.studentLogin(email: '24104048@nec.edu.in', otp: '123456');
      final logout = auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.userNotifier.value, isNull);
      expect(readSessionValue('student_auth_access_token'), isNull);
      pending.complete(http.Response('{}', 200));
      await logout;
    },
  );

  test('Rejected refresh immediately removes an expired session', () async {
    final auth = CustomerAuthService.withClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          return http.Response('{}', 401);
        }
        return http.Response(jsonEncode(tokenResponse()), 200);
      }),
    );
    await auth.studentLogin(email: '24104048@nec.edu.in', otp: '123456');
    expect(await auth.getValidAccessToken(), isNull);
    expect(auth.isLoggedIn, isFalse);
    expect(readSessionValue('student_auth_user_profile'), isNull);
  });

  test(
    'A refresh finishing after logout cannot restore authentication',
    () async {
      final pending = Completer<http.Response>();
      final auth = CustomerAuthService.withClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) return pending.future;
            if (request.url.path.endsWith('/logout')) {
            return http.Response('{}', 200);
            }
          return http.Response(jsonEncode(tokenResponse()), 200);
        }),
      );
      await auth.studentLogin(email: '24104048@nec.edu.in', otp: '123456');
      final refresh = auth.getValidAccessToken();
      await auth.logout();
      pending.complete(http.Response(jsonEncode(tokenResponse()), 200));
      expect(await refresh, isNull);
      expect(auth.accessToken, isNull);
      expect(readSessionValue('student_auth_access_token'), isNull);
    },
  );
}
