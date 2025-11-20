import pytest
import fakeredis
import asyncio
from app.services.rtc_service import publish_audio_chunk


class FakeRedis:
    def __init__(self):
        self._r = fakeredis.FakeRedis()

    async def xadd(self, *args, **kwargs):
        return await asyncio.get_event_loop().run_in_executor(None, lambda: self._r.xadd(*args, **kwargs))

    async def xread(self, *args, **kwargs):
        return await asyncio.get_event_loop().run_in_executor(None, lambda: self._r.xread(*args, **kwargs))


@pytest.mark.asyncio
async def test_publish_audio_chunk(monkeypatch):
    fake = FakeRedis()

    async def _get_fake():
        return fake

    monkeypatch.setattr("app.config.redis.get_redis", _get_fake)

    await publish_audio_chunk("testsess", b"hello world")

    # Use the underlying fakeredis to read
    results = await fake.xread({"stream:audio:testsess": "0-0"}, count=10, block=1)
    assert results
