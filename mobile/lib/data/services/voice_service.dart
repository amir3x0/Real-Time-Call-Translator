import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import 'base_api_service.dart';

class VoiceService extends BaseApiService {
  Future<Map<String, dynamic>> uploadVoiceSample(
      String filePath, String language, String textContent) async {
    final token = await getToken();

    // Build the URI using BaseApiService helper logic manually because MultipartRequest is different
    final uri = Uri.parse('${AppConfig.baseUrl}/api/voice/upload');

    var request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['language'] = language;
    request.fields['text_content'] = textContent;

    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: MediaType('audio', 'wav'),
    );
    request.files.add(file);

    debugPrint('[API] Uploading voice to: $uri');

    final streamedResponse = await request.send();
    final resp = await http.Response.fromStream(streamedResponse);

    debugPrint('[API] Upload response: ${resp.statusCode} - ${resp.body}');

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to upload voice sample: ${resp.body}');
  }

  Future<List<Map<String, dynamic>>> getVoiceRecordings() async {
    try {
      final resp = await get('/api/voice/recordings');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['recordings'] != null) {
          return List<Map<String, dynamic>>.from(data['recordings']);
        }
      }
    } catch (e) {
      debugPrint('Error getting voice recordings: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getVoiceStatus() async {
    try {
      final resp = await get('/api/voice/status');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting voice status: $e');
    }

    return {
      'has_voice_sample': false,
      'voice_model_trained': false,
      'voice_quality_score': null,
      'recordings_count': 0,
    };
  }

  Future<void> deleteVoiceRecording(String recordingId) async {
    await delete('/api/voice/recordings/$recordingId');
  }

  Future<Map<String, dynamic>> trainVoiceModel() async {
    final resp = await post('/api/voice/train');
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to start training');
  }
}
