# Chatterbox TTS Integration Guide

## Overview

This project uses **Resemble AI Chatterbox Multilingual** for text-to-speech synthesis and zero-shot voice cloning. Chatterbox replaces the previously planned Coqui xTTS integration.

## Why Chatterbox?

- **23 Languages Supported**: Including Hebrew (he), English (en), and Russian (ru)
- **Zero-Shot Voice Cloning**: Clone voices from 3-10 second reference audio
- **Sub-200ms Latency**: Real-time capable for interactive communication
- **State-of-the-Art Quality**: Outperforms leading closed-source systems
- **MIT Licensed**: Free and open-source
- **Emotion Control**: Unique exaggeration parameter for expressive speech
- **Cross-Language Support**: Clone English voice and speak in Hebrew, Russian, etc.

## Supported Languages

Full list of 23 supported languages:
- Arabic (ar), Chinese (zh), Danish (da), Dutch (nl), English (en)
- Finnish (fi), French (fr), German (de), Greek (el), Hebrew (he)
- Hindi (hi), Italian (it), Japanese (ja), Korean (ko), Malay (ms)
- Norwegian (no), Polish (pl), Portuguese (pt), Russian (ru), Spanish (es)
- Swahili (sw), Swedish (sv), Turkish (tr)

## Installation

The Chatterbox TTS library is included in `requirements.txt`:

```
chatterbox-tts==0.1.0
```

Install with:
```bash
pip install -r requirements.txt
```

## Configuration

Environment variables in `.env`:

```env
# Chatterbox TTS Settings
CHATTERBOX_DEVICE=cpu           # Use "cuda" for GPU acceleration
CHATTERBOX_VOICE_SAMPLES_DIR=/app/data/voice_samples
CHATTERBOX_MODELS_DIR=/app/data/models
```

## Usage Examples

### Basic Text-to-Speech

```python
from app.services.tts_service import get_tts_service

# Get the service
tts_service = await get_tts_service()

# Synthesize speech
audio_bytes = await tts_service.synthesize(
    text="Hello, this is a test.",
    language="en"
)

# Save to file
with open("output.wav", "wb") as f:
    f.write(audio_bytes)
```

### Voice Cloning (Same Language)

```python
# Clone voice from reference audio
audio_bytes = await tts_service.synthesize(
    text="שלום, זה מבחן של שיבוט קול",
    language="he",
    audio_prompt_path="/path/to/hebrew_speaker.wav"
)
```

### Cross-Language Voice Cloning

```python
# Use English speaker's voice to speak Russian
audio_bytes = await tts_service.clone_voice(
    text="Привет, это тест голосового клонирования",
    reference_audio_path="/path/to/english_speaker.wav",
    target_language="ru"
)
```

### Custom Expressiveness

```python
# More dramatic/emotional speech
audio_bytes = await tts_service.synthesize(
    text="This is exciting news!",
    language="en",
    exaggeration=0.8,      # Higher for more emotion (0.25-2.0)
    cfg_weight=0.3,        # Lower for slower, more dramatic pacing
    temperature=1.2        # Variation in delivery
)
```

## Service Architecture

The TTS service is implemented as a singleton:

```python
from app.services.tts_service import get_tts_service

# Always returns the same initialized instance
service = await get_tts_service()
```

## Performance Considerations

### GPU vs CPU

- **CPU Mode**: Works but slower (~2-5s per synthesis)
- **GPU Mode** (CUDA): Much faster (~0.2-0.5s per synthesis)
- Real-time communication requires GPU for best experience

### Voice Sample Requirements

For optimal voice cloning:
- **Duration**: 3-10 seconds of clear speech
- **Quality**: Clean audio, minimal background noise
- **Format**: WAV, MP3, or other common audio formats
- **Content**: Natural speech, not reading

### Caching Strategy

Recommended caching in Redis:
```python
cache_key = f"tts:{language}:{hash(text)}:{voice_id}"
```

## Parameters Guide

### exaggeration
- **Range**: 0.25 to 2.0
- **Default**: 0.5 (neutral)
- **Higher values**: More emotional/dramatic
- **Lower values**: More monotone/flat

### temperature
- **Range**: 0.05 to 5.0
- **Default**: 1.0
- **Lower values**: More consistent/deterministic
- **Higher values**: More varied/creative

### cfg_weight
- **Range**: 0.0 to 1.0
- **Default**: 0.5 (normal speech)
- **0.0**: Best for cross-language voice cloning
- **Higher values**: Stronger guidance, faster pacing

## Integration with Translation Pipeline

```
1. Speech Recognition (Google STT)
   ↓
2. Translation (Google Translate)
   ↓
3. Voice Cloning (Chatterbox)
   - Load user's voice sample from database
   - Generate translated audio in original voice
   ↓
4. Stream to recipient (WebSocket)
```

## Testing

Run tests with:
```bash
pytest tests/test_tts_service.py -v
```

Mock testing is used to avoid loading the full model during tests.

## Troubleshooting

### Model Loading Issues

If models fail to load:
1. Check available disk space (models are ~500MB)
2. Verify Python version is 3.11+ (officially tested on 3.11)
3. Check CUDA availability if using GPU mode

### Memory Issues

The model requires:
- **CPU**: ~2GB RAM
- **GPU**: ~2GB VRAM

For production, ensure adequate resources.

### Quality Issues

If synthesis quality is poor:
1. Use clean reference audio for voice cloning
2. Adjust `exaggeration` parameter (try 0.5-0.7 range)
3. Lower `temperature` for more consistent output
4. Ensure correct language code

## References

- **HuggingFace Model**: https://huggingface.co/ResembleAI/chatterbox
- **GitHub Repository**: https://github.com/resemble-ai/chatterbox
- **PyPI Package**: https://pypi.org/project/chatterbox-tts/
- **Official Website**: https://www.resemble.ai/chatterbox/

## Migration from Coqui xTTS

This project was originally planned to use Coqui xTTS but switched to Chatterbox for:
- Better multilingual support (23 vs ~13 languages)
- Faster inference (sub-200ms vs ~500ms)
- Easier zero-shot cloning (no training required)
- Active development and support
- MIT license

## License

Chatterbox is MIT licensed and free for commercial use. All generated audio includes imperceptible neural watermarks for responsible AI deployment.
