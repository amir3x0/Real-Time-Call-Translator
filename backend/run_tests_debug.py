import pytest
import sys
import os

# Ensure we are in backend directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("Starting tests...")
retcode = pytest.main(["tests/test_auth_api.py", "tests/test_calls_api.py"])
print(f"Tests finished with exit code: {retcode}")
