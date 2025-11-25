import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/auth_provider.dart';

void main() {
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
      final loginFuture = authProvider.login('test@test.com', '123456');
      expect(authProvider.isLoading, true);

      // 2. Wait for login to complete
      final success = await loginFuture;

      // 3. Verify results
      expect(success, true);
      expect(authProvider.isLoading, false);
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser!.email, 'test@test.com');
      expect(authProvider.isAuthenticated, true);
    });

    test('Logout should clear user data', () async {
      // Login first
      await authProvider.login('test@test.com', '123456');
      expect(authProvider.isAuthenticated, true);

      // Logout
      authProvider.logout();

      // Verify
      expect(authProvider.currentUser, null);
      expect(authProvider.isAuthenticated, false);
    });
  });
}