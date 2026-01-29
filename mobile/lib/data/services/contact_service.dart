/// Contact Service - Contact management via REST API.
///
/// Handles all contact-related API operations:
/// - Fetching user's contact list
/// - Searching for users to add as contacts
/// - Adding/deleting contacts
/// - Accepting/rejecting contact requests
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_api_service.dart';

/// Service for managing user contacts via REST API.
class ContactService extends BaseApiService {
  Future<Map<String, dynamic>> getContacts() async {
    try {
      final resp = await get('/api/contacts');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        if (data is List) {
          return {'contacts': List<Map<String, dynamic>>.from(data)};
        }
      }
    } catch (e) {
      debugPrint('Error getting contacts: $e');
    }
    return {'contacts': []};
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final resp = await get('/api/contacts/search', query: {'q': query});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['users'] != null) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> addContact(String contactUserId) async {
    final resp = await post('/api/contacts/add/$contactUserId');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add contact');
  }

  Future<void> deleteContact(String contactId) async {
    await delete('/api/contacts/$contactId');
  }

  Future<void> acceptContactRequest(String requestId) async {
    final resp = await post('/api/contacts/$requestId/accept');
    if (resp.statusCode != 200) {
      throw Exception('Failed to accept request: ${resp.body}');
    }
  }

  Future<void> rejectContactRequest(String requestId) async {
    final resp = await post('/api/contacts/$requestId/reject');
    if (resp.statusCode != 200) {
      throw Exception('Failed to reject request: ${resp.body}');
    }
  }
}
