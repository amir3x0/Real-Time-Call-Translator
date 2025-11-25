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
}