import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('AuthProvider Tests', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider();
    });

    test('Initial state should be logged out', () {
      expect(authProvider.currentUser, null);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.isLoading, false);
    });

    test('Login should update user and loading state', () async {
      // 1. Check loading starts
      final loginFuture = authProvider.login('052-111-2222', '123456');
      expect(authProvider.isLoading, true);

      // 2. Wait for login to complete
      final success = await loginFuture;

      // 3. Verify results
      expect(success, true);
      expect(authProvider.isLoading, false);
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser!.phone, '052-111-2222');
      expect(authProvider.isAuthenticated, true);
    });

    test('Logout should clear user data', () async {
      // Login first
      await authProvider.login('052-111-2222', '123456');
      expect(authProvider.isAuthenticated, true);

      // Logout
      authProvider.logout();

      // Verify
      expect(authProvider.currentUser, null);
      expect(authProvider.isAuthenticated, false);
    });
  });
}