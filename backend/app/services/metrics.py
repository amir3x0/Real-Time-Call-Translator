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
