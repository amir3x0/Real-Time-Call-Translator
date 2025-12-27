import 'dart:math';

import '../../models/participant.dart';
import '../../models/user.dart';
import '../../models/contact.dart';
import '../../widgets/shared/language_selector.dart';

/// Centralized mock data for the Real-Time Call Translator app.
/// 
/// This class provides all mock data, random generators, and helper
/// functions used across the app during development. When connecting
/// to a real backend, replace usages with actual API calls.
class MockData {
  static final Random _random = Random();

  // ========== Mock Users (with full User model) ==========
  static final List<User> mockUsers = [
    User(
      id: 'u1',
      phone: '052-111-1111',
      fullName: 'Daniel Fraimovich',
      primaryLanguage: 'ru',
      isOnline: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    User(
      id: 'u2',
      phone: '052-222-2222',
      fullName: 'Emma Cohen',
      primaryLanguage: 'en',
      isOnline: true,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    User(
      id: 'u3',
      phone: '052-333-3333',
      fullName: 'Noa Levy',
      primaryLanguage: 'he',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    User(
      id: 'u4',
      phone: '052-444-4444',
      fullName: 'Igor Petrov',
      primaryLanguage: 'ru',
      isOnline: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    User(
      id: 'u5',
      phone: '052-555-5555',
      fullName: 'Sarah Williams',
      primaryLanguage: 'en',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    User(
      id: 'u6',
      phone: '052-666-6666',
      fullName: 'Amir Mishayev',
      primaryLanguage: 'he',
      hasVoiceSample: true,
      voiceModelTrained: true,
      voiceQualityScore: 85,
      isOnline: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  // ========== Mock Transcription Messages ==========
  static const List<Map<String, String>> transcriptionMessages = [
    {
      'original': 'Hello, how are you?',
      'translated': 'שלום, מה שלומך?',
      'source': 'en',
      'target': 'he',
    },
    {
      'original': 'Привет, как дела?',
      'translated': 'Hey, how\'s it going?',
      'source': 'ru',
      'target': 'en',
    },
    {
      'original': 'אני בסדר, תודה',
      'translated': 'I\'m fine, thanks',
      'source': 'he',
      'target': 'en',
    },
    {
      'original': 'The meeting is at 3pm',
      'translated': 'הפגישה ב-3 אחה"צ',
      'source': 'en',
      'target': 'he',
    },
    {
      'original': 'Отлично, увидимся',
      'translated': 'Great, see you',
      'source': 'ru',
      'target': 'en',
    },
    {
      'original': 'מתי אתה פנוי?',
      'translated': 'When are you free?',
      'source': 'he',
      'target': 'en',
    },
    {
      'original': 'Let me check my calendar',
      'translated': 'תן לי לבדוק את היומן שלי',
      'source': 'en',
      'target': 'he',
    },
    {
      'original': 'Хорошо, договорились',
      'translated': 'OK, agreed',
      'source': 'ru',
      'target': 'en',
    },
  ];

  // ========== Legacy Names (for compatibility) ==========
  static const List<String> names = [
    'Daniel Fraimovich',
    'Emma Cohen',
    'Noa Levy',
    'Igor Petrov',
    'Amir Mishayev',
    'Lena Volkov',
    'Sasha Kim',
    'Yael Goldstein',
    'Omer Ben-David',
    'Svetlana Ivanova',
    'Michael Ross',
    'Anna Shapiro',
  ];

  static const List<String> firstNames = [
    'Daniel', 'Emma', 'Noa', 'Igor', 'Amir', 'Lena',
    'Sasha', 'Yael', 'Omer', 'Svetlana', 'Michael', 'Anna',
  ];

  // ========== Connection Qualities ==========
  static const List<String> connectionQualities = [
    'excellent',
    'good', 
    'fair',
    'poor',
  ];

  // ========== Legacy Transcription Messages (simple strings) ==========
  static const List<String> legacyTranscriptionMessages = [
    'Hello, how are you? \u2014 \u05e9\u05dc\u05d5\u05dd, \u05de\u05d4 \u05e9\u05dc\u05d5\u05de\u05da?',
    'The meeting starts at 3 \u2014 \u05d4\u05e4\u05d2\u05d9\u05e9\u05d4 \u05de\u05ea\u05d7\u05d9\u05dc\u05d4 \u05d1-3',
    'I understand \u2014 \u05d0\u05e0\u05d9 \u05de\u05d1\u05d9\u05df',
    'Can you repeat? \u2014 \u05d0\u05ea\u05d4 \u05d9\u05db\u05d5\u05dc \u05dc\u05d7\u05d6\u05d5\u05e8?',
    'Great idea! \u2014 \u05e8\u05e2\u05d9\u05d5\u05df \u05de\u05e6\u05d5\u05d9\u05df!',
    'Let me think about it \u2014 \u05ea\u05df \u05dc\u05d9 \u05dc\u05d7\u05e9\u05d5\u05d1 \u05e2\u05dc \u05d6\u05d4',
    'Yes, exactly \u2014 \u05db\u05df, \u05d1\u05d3\u05d9\u05d5\u05e7',
    'See you tomorrow \u2014 \u05e0\u05ea\u05e8\u05d0\u05d4 \u05de\u05d7\u05e8',
  ];

  // ========== Phone Number Prefixes ==========
  static const List<String> phonePrefixes = [
    '050', '052', '053', '054', '055', '058',
  ];

  // ========== Random Generators ==========
  
  /// Returns a random full name
  static String randomName() => names[_random.nextInt(names.length)];
  
  /// Returns a random first name
  static String randomFirstName() => firstNames[_random.nextInt(firstNames.length)];
  
  /// Returns a random language code
  static String randomLanguage() {
    final codes = LanguageData.supportedLanguages.map((l) => l.code).toList();
    return codes[_random.nextInt(codes.length)];
  }

  /// Returns a random language code different from the given one
  static String randomLanguageExcept(String exceptCode) {
    final codes = LanguageData.supportedLanguages
        .map((l) => l.code)
        .where((code) => code != exceptCode)
        .toList();
    return codes[_random.nextInt(codes.length)];
  }
  
  /// Returns a random connection quality
  static String randomConnectionQuality() => 
      connectionQualities[_random.nextInt(connectionQualities.length)];
  
  /// Returns a random transcription message (legacy simple string)
  static String randomTranscription() => 
      legacyTranscriptionMessages[_random.nextInt(legacyTranscriptionMessages.length)];

  /// Returns a random structured transcription message
  static Map<String, String> randomTranscriptionEntry() =>
      transcriptionMessages[_random.nextInt(transcriptionMessages.length)];

  /// Returns a random Israeli phone number
  static String randomPhoneNumber() {
    final prefix = phonePrefixes[_random.nextInt(phonePrefixes.length)];
    final number = List.generate(7, (_) => _random.nextInt(10)).join();
    return '$prefix-${number.substring(0, 3)}-${number.substring(3)}';
  }

  /// Returns a random boolean
  static bool randomBool() => _random.nextBool();

  /// Returns a random integer in range [0, max)
  static int randomInt(int max) => _random.nextInt(max);

  /// Returns a random double in range [0.0, 1.0)
  static double randomDouble() => _random.nextDouble();

  // ========== Mock Entity Generators ==========

  /// Creates a mock CallParticipant
  static CallParticipant createMockParticipant({
    String? id,
    String? callId,
    String? displayName,
    String? speakingLanguage,
    String? targetLanguage,
    String? connectionQuality,
    bool? isMuted,
    bool? isSpeaking,
  }) {
    final participantId = id ?? 'p${DateTime.now().millisecondsSinceEpoch}_${randomInt(1000)}';
    final speaking = speakingLanguage ?? randomLanguage();
    
    return CallParticipant(
      id: participantId,
      callId: callId ?? 'c1',
      userId: 'u${randomInt(10000)}',
      displayName: displayName ?? randomFirstName(),
      speakingLanguage: speaking,
      targetLanguage: targetLanguage ?? randomLanguageExcept(speaking),
      connectionQuality: connectionQuality ?? randomConnectionQuality(),
      isMuted: isMuted ?? randomBool(),
      isSpeaking: isSpeaking ?? false,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
      isConnected: true,
    );
  }

  /// Creates a list of mock participants
  static List<CallParticipant> createMockParticipants(int count, {String? callId}) {
    return List.generate(count, (index) => createMockParticipant(
      id: 'p${index + 1}',
      callId: callId,
    ));
  }

  /// Creates a set of demo participants for the active call screen
  static List<CallParticipant> createDemoParticipants() {
    return [
      CallParticipant(
        id: 'p1',
        callId: 'c1',
        userId: 'u1',
        targetLanguage: 'he',
        speakingLanguage: 'en',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'excellent',
        isMuted: false,
        displayName: 'Daniel',
      ),
      CallParticipant(
        id: 'p2',
        callId: 'c1',
        userId: 'u2',
        targetLanguage: 'en',
        speakingLanguage: 'ru',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'good',
        isMuted: true,
        displayName: 'Emma',
      ),
      CallParticipant(
        id: 'p3',
        callId: 'c1',
        userId: 'u3',
        targetLanguage: 'ru',
        speakingLanguage: 'en',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'fair',
        isMuted: false,
        displayName: 'Noa',
      ),
      CallParticipant(
        id: 'p4',
        callId: 'c1',
        userId: 'u4',
        targetLanguage: 'en',
        speakingLanguage: 'he',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'excellent',
        isMuted: false,
        displayName: 'Igor',
      ),
    ];
  }

  // ========== User Lookup Methods ==========
  
  /// Find a mock user by phone number
  static User? findUserByPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return mockUsers.cast<User?>().firstWhere(
      (u) => (u?.phone ?? '').replaceAll(RegExp(r'\D'), '') == normalized,
      orElse: () => null,
    );
  }

  /// Find a mock user by ID
  static User? findUserById(String id) {
    return mockUsers.cast<User?>().firstWhere(
      (u) => u!.id == id,
      orElse: () => null,
    );
  }

  /// Get the current mock user (for testing)
  /// Returns user with ID 'u6' (Amir) as the default current user
  static User get currentMockUser => mockUsers.firstWhere((u) => u.id == 'u6');

  /// Get mock contacts for a user (excluding the user themselves)
  static List<Contact> getMockContactsForUser(String userId) {
    final otherUsers = mockUsers.where((u) => u.id != userId).toList();
    return otherUsers.take(4).indexed.map((entry) {
      final (index, user) = entry;
      return Contact(
        id: 'contact_${user.id}',
        userId: userId,
        contactUserId: user.id,
        contactName: null, // Use user's real name
        isBlocked: false,
        isFavorite: index == 0, // First contact is favorite for demo
        addedAt: DateTime.now().subtract(Duration(days: randomInt(30))),
        createdAt: DateTime.now().subtract(Duration(days: randomInt(30))),
        // Joined user info
        fullName: user.fullName,
        phone: user.phone,
        primaryLanguage: user.primaryLanguage,
        isOnline: user.isOnline,
      );
    }).toList();
  }

  /// Get weighted random connection quality (biased towards good)
  static String randomWeightedConnectionQuality() {
    final weights = [0.4, 0.35, 0.2, 0.05]; // excellent, good, fair, poor
    final r = randomDouble();
    var cumulative = 0.0;
    for (var i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (r <= cumulative) return connectionQualities[i];
    }
    return 'good';
  }
}

/// Mock contact for UI display (legacy - kept for compatibility)
class MockContact {
  final String id;
  final String name;
  final String phone;
  final String languageCode;
  final bool isOnline;
  final DateTime? lastSeen;

  const MockContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.languageCode,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Creates a random mock contact
  factory MockContact.random() {
    return MockContact(
      id: 'contact_${DateTime.now().millisecondsSinceEpoch}_${MockData.randomInt(1000)}',
      name: MockData.randomName(),
      phone: MockData.randomPhoneNumber(),
      languageCode: MockData.randomLanguage(),
      isOnline: MockData.randomBool(),
      lastSeen: DateTime.now().subtract(Duration(minutes: MockData.randomInt(1440))),
    );
  }

  /// Creates a list of random mock contacts
  static List<MockContact> generateList(int count) {
    return List.generate(count, (_) => MockContact.random());
  }
}
