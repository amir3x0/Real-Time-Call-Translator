import 'package:mobile/data/services/auth_service.dart';
import 'package:mobile/data/services/call_api_service.dart';
import 'package:mobile/data/services/contact_service.dart';
import 'package:mobile/models/user.dart';

class FakeAuthService extends AuthService {
  final bool shouldFail;
  final int delayMs;

  FakeAuthService({this.shouldFail = false, this.delayMs = 50});

  @override
  Future<User> login(String phone, String password) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    if (shouldFail) throw Exception('Login failed');
    return User(
      id: 'test_user_id',
      phone: phone,
      fullName: 'Test User',
      primaryLanguage: 'en',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<User> register(String phone, String fullName, String password,
      String primaryLanguage) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    if (shouldFail) throw Exception('Registration failed');
    return User(
      id: 'new_user_id',
      phone: phone,
      fullName: fullName,
      primaryLanguage: primaryLanguage,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<User?> me() async {
    await Future.delayed(Duration(milliseconds: delayMs));
    if (shouldFail) return null;
    return User(
      id: 'test_user_id',
      phone: '052-111-2222',
      fullName: 'Test User',
      primaryLanguage: 'en',
      createdAt: DateTime.now(),
    );
  }
}

class FakeContactService extends ContactService {
  final bool shouldFail;

  FakeContactService({this.shouldFail = false});

  @override
  Future<Map<String, dynamic>> getContacts() async {
    if (shouldFail) throw Exception('Failed to get contacts');
    return {
      'contacts': [],
      'pending_incoming': [],
      'pending_outgoing': [],
    };
  }
}

class FakeCallApiService extends CallApiService {
  // Add methods as needed for testing
}
