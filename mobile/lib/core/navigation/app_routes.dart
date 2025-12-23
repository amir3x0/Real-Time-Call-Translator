/// App navigation routes for the Real-Time Call Translator.
/// 
/// Centralized route management following the redesigned architecture.
class AppRoutes {
  // ========== Auth Flow ==========
  /// Login screen - initial route for unauthenticated users
  static const String login = '/';
  
  /// Registration screen
  static const String register = '/register';
  
  /// Voice sample setup screen (optional during registration)
  static const String voiceSetup = '/register/voice';

  // ========== Main App ==========
  /// Home screen with tabs (Contacts, Recents, Settings)
  static const String home = '/home';

  // ========== Call Flow ==========
  /// Select participants for a new call
  static const String selectParticipants = '/call/select';
  
  /// Confirm call before starting (shows participants + languages)
  static const String callConfirmation = '/call/confirm';
  
  /// Incoming call screen (accept/reject)
  static const String incomingCall = '/call/incoming';
  
  /// Active call screen with real-time translation
  static const String activeCall = '/call/active';

  // ========== Contacts ==========
  /// Contacts list (also available as tab in home)
  static const String contacts = '/contacts';
  
  /// Add new contact screen
  static const String addContact = '/contacts/add';

  // ========== Settings ==========
  /// Settings screen
  static const String settings = '/settings';
  
  /// Edit profile settings
  static const String editProfile = '/settings/profile';
  
  /// Voice settings (manage voice sample)
  static const String voiceSettings = '/settings/voice';

  // ========== Helpers ==========
  
  /// Check if route is part of auth flow
  static bool isAuthRoute(String route) {
    return route == login || 
           route == register || 
           route == voiceSetup;
  }

  /// Check if route is part of call flow
  static bool isCallRoute(String route) {
    return route == selectParticipants || 
           route == callConfirmation || 
           route == incomingCall ||
           route == activeCall;
  }

  /// Get route name for analytics/logging
  static String getRouteName(String route) {
    switch (route) {
      case login: return 'Login';
      case register: return 'Register';
      case voiceSetup: return 'Voice Setup';
      case home: return 'Home';
      case selectParticipants: return 'Select Participants';
      case callConfirmation: return 'Call Confirmation';
      case incomingCall: return 'Incoming Call';
      case activeCall: return 'Active Call';
      case contacts: return 'Contacts';
      case addContact: return 'Add Contact';
      case settings: return 'Settings';
      case editProfile: return 'Edit Profile';
      case voiceSettings: return 'Voice Settings';
      default: return 'Unknown';
    }
  }
}
