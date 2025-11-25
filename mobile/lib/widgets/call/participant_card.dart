import 'package:flutter/material.dart';
import '../../models/participant.dart';
import '../../config/app_config.dart';

class ParticipantCard extends StatelessWidget {
  final CallParticipant participant;
  // We'll simulate names since Participant model only has UserID
  final String mockName;

  const ParticipantCard({
    super.key,
    required this.participant,
    this.mockName = "User",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        border: Border.all(
          color: Color(
            int.parse(participant.connectionColor.replaceFirst('#', '0xff')),
          ),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blueGrey,
              child: Text(
                mockName[0],
                style: const TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
          ),

          // Name & Flag
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(mockName, style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 5),
                  // Mock Flag based on speaking language
                  Text(
                    participant.speakingLanguage == 'he'
                        ? '🇮🇱'
                        : participant.speakingLanguage == 'ru'
                        ? '🇷🇺'
                        : '🇺🇸',
                  ),
                ],
              ),
            ),
          ),

          // Mute Icon
          if (participant.isMuted)
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.mic_off, color: Colors.red),
            ),
        ],
      ),
    );
  }
}
