"""Business Logic Services.

This package contains all service modules that implement the core
business logic of the Real-Time Call Translator.

Service Categories:
- Audio: Audio processing, chunking, speech detection
- Call: Call lifecycle, participants, history
- Connection: WebSocket connection management
- Translation: Translation processing, TTS caching
- Session: WebSocket session orchestration
- Core: Repositories, deduplication utilities

External integrations:
- gcp_pipeline: Google Cloud Speech, Translation, TTS
- interim_caption_service: Real-time streaming captions
"""
