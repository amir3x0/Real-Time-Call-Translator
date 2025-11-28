import 'dart:math';

import '../../models/participant.dart';
import '../../widgets/shared/language_selector.dart';

/// Centralized mock data for the Real-Time Call Translator app.
/// 
/// This class provides all mock data, random generators, and helper
/// functions used across the app during development. When connecting
/// to a real backend, replace usages with actual API calls.
class MockData {
  static final Random _random = Random();

  // ========== Names ==========
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

  // ========== Mock Transcription Messages ==========
  static const List<String> transcriptionMessages = [
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
  
  /// Returns a random transcription message
  static String randomTranscription() => 
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
}

/// Mock contact for UI display
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
