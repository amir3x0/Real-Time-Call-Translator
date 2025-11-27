import sys
from pathlib import Path

# Add project root (2 levels up from tests/) to sys.path so tests can import 'app'
root = Path(__file__).resolve().parents[1]
if str(root) not in sys.path:
    sys.path.insert(0, str(root))


# Optionally set PYTHONPATH for runtime
import os
os.environ.setdefault('PYTHONPATH', str(root))
