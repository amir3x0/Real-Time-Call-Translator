import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transcription_entry.dart';
import '../../models/interim_caption.dart';
import '../../config/app_theme.dart';
import 'chat_message_bubble.dart';
import 'live_message_bubble.dart';

/// Chat-like transcription view with message bubbles.
///
/// Features:
/// - Scrollable message history
/// - Multiple live interim bubbles (multi-speaker support)
/// - Different styling for self vs others
/// - Auto-scroll to newest messages
/// - Animated message appearance
class ChatTranscriptionView extends StatefulWidget {
  const ChatTranscriptionView({
    super.key,
    required this.entries,
    required this.currentUserId,
    this.interimCaptions = const [],
    this.maxMessages = 20,
  });

  final List<TranscriptionEntry> entries;
  final String currentUserId;
  final List<InterimCaption> interimCaptions;
  final int maxMessages;

  @override
  State<ChatTranscriptionView> createState() => _ChatTranscriptionViewState();
}

class _ChatTranscriptionViewState extends State<ChatTranscriptionView> {
  final ScrollController _scrollController = ScrollController();
  int _previousEntryCount = 0;
  int _previousInterimCount = 0;

  @override
  void initState() {
    super.initState();
    _previousEntryCount = widget.entries.length;
    _previousInterimCount = widget.interimCaptions.length;
  }

  @override
  void didUpdateWidget(ChatTranscriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when new messages or interim captions arrive
    final hasNewEntries = widget.entries.length > _previousEntryCount;
    final hasNewInterim = widget.interimCaptions.length > _previousInterimCount;

    if (hasNewEntries || hasNewInterim) {
      _previousEntryCount = widget.entries.length;
      _previousInterimCount = widget.interimCaptions.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for every rebuild
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[ChatTranscriptionView] BUILD called');
    debugPrint('[ChatTranscriptionView] entries.length: ${widget.entries.length}');
    debugPrint('[ChatTranscriptionView] currentUserId: "${widget.currentUserId}"');
    debugPrint('[ChatTranscriptionView] interimCaptions.length: ${widget.interimCaptions.length}');
    if (widget.entries.isNotEmpty) {
      for (int i = 0; i < widget.entries.length && i < 5; i++) {
        final e = widget.entries[i];
        debugPrint('[ChatTranscriptionView]   Entry[$i]: participantId="${e.participantId}", isSelf=${e.participantId == widget.currentUserId}, text="${e.originalText.length > 20 ? '${e.originalText.substring(0, 20)}...' : e.originalText}"');
      }
    }
    debugPrint('═══════════════════════════════════════════════════════════');

    final hasContent =
        widget.entries.isNotEmpty || widget.interimCaptions.isNotEmpty;

    if (!hasContent) {
      return _buildEmptyState();
    }

    // Limit visible entries
    final visibleEntries = widget.entries.length > widget.maxMessages
        ? widget.entries.sublist(widget.entries.length - widget.maxMessages)
        : widget.entries;

    return Column(
      children: [
        // Message list (final entries only)
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            itemCount: visibleEntries.length,
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              final isSelf = entry.participantId == widget.currentUserId;
              final shouldAnimate =
                  index >= visibleEntries.length - 3 && visibleEntries.length > 3;

              return ChatMessageBubble(
                entry: entry,
                isSelf: isSelf,
                animate: shouldAnimate,
              );
            },
          ),
        ),

        // Live interim bubbles (multiple speakers supported)
        if (widget.interimCaptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.interimCaptions.map((caption) {
                return LiveMessageBubble(
                  key: ValueKey('live_${caption.speakerId}'),
                  text: caption.text,
                  speakerName: caption.speakerName ?? caption.displayTag,
                  isSelf: caption.isSelf,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                AppTheme.accentCyan.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Listening...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.secondaryText.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}
