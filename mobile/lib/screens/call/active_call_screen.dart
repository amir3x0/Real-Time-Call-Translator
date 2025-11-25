import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call/participant_card.dart';

class ActiveCallScreen extends StatelessWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("00:45", style: TextStyle(color: Colors.white)), // Mock Timer
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Participants Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
              ),
              itemCount: callProvider.participants.length,
              itemBuilder: (context, index) {
                final participant = callProvider.participants[index];
                return ParticipantCard(
                  participant: participant,
                  mockName: index == 0 ? "Daniel" : "Guest",
                );
              },
            ),
          ),

          // Subtitles Area
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.black54,
            child: Text(
              callProvider.liveTranscription,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.yellowAccent, fontSize: 18),
            ),
          ),

          // Control Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(Icons.mic, Colors.white, () {}),
                _buildControlButton(Icons.volume_up, Colors.white, () {}),
                _buildControlButton(Icons.call_end, Colors.red, () {
                  callProvider.endCall();
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}