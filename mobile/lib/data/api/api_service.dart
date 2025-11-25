import '../../models/user.dart';

class ApiService {
  Future<User> login(String email, String password) async {
    // Mock network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock User Response
    return User(
      id: '1',
      email: email,
      name: 'Amir Mishayev',
      primaryLanguage: 'he',
      supportedLanguages: ['he', 'en'],
      createdAt: DateTime.now(),
      avatarUrl: 'https://i.pravatar.cc/150?img=11', // Random avatar
    );
  }

  // Mock Contacts endpoints
  Future<List<Map<String, dynamic>>> getContacts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'id': 'c1', 'name': 'Daniel Fraimovich', 'language': 'ru', 'status': 'Online'},
      {'id': 'c2', 'name': 'Dr. Dan Lemberg', 'language': 'he', 'status': 'Away'},
      {'id': 'c3', 'name': 'John Doe', 'language': 'en', 'status': 'Offline'},
    ];
  }

  Future<Map<String, dynamic>> createContact(String name, String language) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': name, 'language': language, 'status': 'Online'};
  }

  Future<void> deleteContact(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return;
  }

  // Mock Voice sample endpoints
  Future<Map<String, dynamic>> uploadVoiceSample(String userId, String filePath) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'success': true, 'path': '/mock/voice_samples/$userId.wav'};
  }

  Future<void> deleteVoiceSample(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return;
  }
}