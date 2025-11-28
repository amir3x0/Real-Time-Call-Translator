import '../../models/user.dart';

class ApiService {
  Future<User> login(String phone, String password) async {
    // Mock network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock User Response
    return User(
      id: '1',
      phone: phone,
      fullName: 'Amir Mishayev',
      primaryLanguage: 'he',
      supportedLanguages: ['he', 'en'],
      createdAt: DateTime.now(),
      avatarUrl: 'https://i.pravatar.cc/150?img=11', // Random avatar
    );
  }

  Future<User> register(String phone, String fullName, String password, String primaryLanguage) async {
    // Mock register flow
    await Future.delayed(const Duration(seconds: 1));
    return User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      phone: phone,
      fullName: fullName,
      primaryLanguage: primaryLanguage,
      supportedLanguages: [primaryLanguage],
      createdAt: DateTime.now(),
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
    );
  }

  // Mock Contacts endpoints
  Future<List<Map<String, dynamic>>> getContacts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'id': 'c1', 'name': 'Daniel Fraimovich', 'phone': '052-123-4567', 'language': 'ru', 'status': 'Online'},
      {'id': 'c2', 'name': 'Dr. Dan Lemberg', 'phone': '054-987-6543', 'language': 'he', 'status': 'Away'},
      {'id': 'c3', 'name': 'John Doe', 'phone': '058-555-1234', 'language': 'en', 'status': 'Offline'},
    ];
  }

  Future<Map<String, dynamic>> createContact(String name, String language, {required String phone}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'phone': phone,
      'language': language,
      'status': 'Offline',
    };
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

  Future<Map<String, dynamic>> startCall(List<String> participantUserIds) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    return {
      'session_id': sessionId,
      'websocket_url': 'ws://10.0.2.2:8000/ws/$sessionId',
      'participants': participantUserIds.map((id) => {
            'id': 'p$id',
            'user_id': id,
            'display_name': 'Mock User $id',
            'phone': '052-000-000$id',
            'target_language': 'en',
            'speaking_language': 'en',
            'joined_at': now,
            'created_at': now,
          }).toList(),
    };
  }
}