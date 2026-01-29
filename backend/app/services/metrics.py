"""Prometheus metrics instrumentation for audio processing pipeline.

Exposes metrics for monitoring latency, throughput, and error rates
of the real-time translation pipeline. Metrics are exposed via HTTP
on port 8001 (configurable).

Metrics exported:
- audio_processing_latency_seconds: Histogram of processing time per stage
- audio_segments_processed_total: Counter of processed segments by status
- audio_active_streams: Gauge of currently active audio streams
- audio_silence_triggers_total: Counter of silence-triggered processing events

Usage:
    from app.services.metrics import start_metrics_server, segments_processed

    start_metrics_server(port=8001)
    segments_processed.labels(status='success', language_pair='he-en').inc()
"""

from prometheus_client import Histogram, Counter, Gauge, start_http_server
import logging

logger = logging.getLogger(__name__)

# Latency tracking per component
audio_processing_latency = Histogram(
    'audio_processing_latency_seconds',
    'Time spent in each processing stage',
    labelnames=['component', 'language_pair']
)

# Segment processing counters
segments_processed = Counter(
    'audio_segments_processed_total',
    'Total audio segments processed',
    labelnames=['status', 'language_pair']  # status: success, error, empty
)

# Active streams gauge
active_streams_gauge = Gauge(
    'audio_active_streams',
    'Number of currently active audio streams'
)

# Silence detection metrics
silence_triggers = Counter(
    'audio_silence_triggers_total',
    'Number of times silence triggered processing',
    labelnames=['trigger_type']  # trigger_type: pause, max_chunks, end_stream
)

def start_metrics_server(port: int = 8001):
    """Start Prometheus metrics HTTP server."""
    try:
        start_http_server(port)
        logger.info(f"✅ Metrics server started on port {port}")
    except Exception as e:
        logger.error(f"❌ Failed to start metrics server: {e}")
