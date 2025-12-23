import asyncio
import httpx
import websockets
import json
import logging
import sys

import os

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
WS_URL = os.getenv("WS_URL", "ws://localhost:8000")

async def register_user(client, name, phone, password, language="en"):
    url = f"{BASE_URL}/api/auth/register"
    data = {
        "phone": phone,
        "password": password,
        "full_name": name,
        "primary_language": language
    }
    try:
        resp = await client.post(url, json=data)
        if resp.status_code == 201:
            logger.info(f"Registered {name}")
            return resp.json()
        elif resp.status_code == 409: # Already exists
             logger.info(f"User {name} likely exists, trying login")
             return await login_user(client, phone, password)
        else:
            logger.error(f"Failed to register {name}: {resp.status_code} {resp.text}")
            return None
    except Exception as e:
        logger.error(f"Request Error (Register): {e}")
        return None

async def login_user(client, phone, password):
    url = f"{BASE_URL}/api/auth/login"
    data = {
        "phone": phone,
        "password": password
    }
    try:
        resp = await client.post(url, json=data) # Changed to json for standard API
        if resp.status_code == 200:
            logger.info(f"Logged in {phone}")
            return resp.json()
        else:
            logger.error(f"Failed to login {phone}: {resp.status_code} {resp.text}")
            return None
    except Exception as e:
        logger.error(f"Request Error (Login): {e}")
        return None

async def connect_lobby(user_id, event_queue):
    ws_url = f"{WS_URL}/ws/lobby?user_id={user_id}"
    logger.info(f"Connecting to Lobby: {ws_url}")
    try:
        async with websockets.connect(ws_url) as ws:
            logger.info(f"Connected to Lobby ({user_id})")
            
            # Wait for connected message
            msg = await ws.recv()
            logger.info(f"Received: {msg}")
            
            # Keep alive and listen
            async for msg in ws:
                data = json.loads(msg)
                logger.info(f"[{user_id}] WS Message: {data['type']}")
                await event_queue.put(data)
                
    except Exception as e:
        logger.error(f"Lobby Error ({user_id}): {e}")

async def run_scenario():
    async with httpx.AsyncClient() as client:
        # 1. Setup User A
        user_a = await register_user(client, "User A", "0501111111", "password123")
        if not user_a: return
        token_a = user_a['token']
        resp = await client.get(f"{BASE_URL}/api/auth/me", headers={"Authorization": f"Bearer {token_a}"})
        id_a = resp.json()['id']

        # 2. Setup User B
        user_b = await register_user(client, "User B", "0502222222", "password123")
        if not user_b: return
        token_b = user_b['token']
        resp = await client.get(f"{BASE_URL}/api/auth/me", headers={"Authorization": f"Bearer {token_b}"})
        id_b = resp.json()['id']
        
        logger.info(f"User A: {id_a}, User B: {id_b}")

        # 3. Start Lobby for User B
        event_queue_b = asyncio.Queue()
        task_b = asyncio.create_task(connect_lobby(id_b, event_queue_b))
        
        await asyncio.sleep(1)
        
        # 4. A requests B
        logger.info("User A sending Friend Request to User B...")
        resp = await client.post(
            f"{BASE_URL}/api/contacts/add/{id_b}",
            headers={"Authorization": f"Bearer {token_a}"}
        )
        if resp.status_code not in [200, 201]:
            logger.error(f"Add Contract Failed: {resp.text}")
            if "already" not in resp.text: return
        else:
            logger.info("Friend Request Sent")

        # 5. B waits for notification
        logger.info("Waiting for B to receive request...")
        try:
            while True:
                event = await asyncio.wait_for(event_queue_b.get(), timeout=5.0)
                if event['type'] == 'contact_request':
                    logger.info("SUCCESS: B received contact_request!")
                    request_id = event['request_id']
                    
                    # 6. B Accepts Request
                    logger.info(f"B accepting request {request_id}...")
                    resp = await client.post(
                        f"{BASE_URL}/api/contacts/{request_id}/accept",
                        headers={"Authorization": f"Bearer {token_b}"}
                    )
                    assert resp.status_code == 200
                    logger.info("SUCCESS: Request Accepted")
                    break
        except asyncio.TimeoutError:
            logger.warning("Timeout waiting for contact request (maybe already friends?)")

        # 7. A calls B (Validation: Should succeed without skip_contact_validation)
        logger.info("User A initiating call to User B (Friends Verification)...")
        call_data = {
            "participant_user_ids": [id_b], 
            "call_language": "en"
            # note: skip_contact_validation is False by default
        }
        resp = await client.post(
            f"{BASE_URL}/api/calls/start", 
            json=call_data, 
            headers={"Authorization": f"Bearer {token_a}"}
        )
        
        if resp.status_code == 200:
            logger.info("Call Started Successfully! (Friendship Validated)")
        else:
            logger.error(f"Call Failed: {resp.status_code} {resp.text}")
            return

        # 8. Wait for Incoming Call on B
        try:
            while True:
                event = await asyncio.wait_for(event_queue_b.get(), timeout=5.0)
                if event['type'] == 'incoming_call':
                    logger.info("SUCCESS: B received incoming call!")
                    break
        except asyncio.TimeoutError:
            logger.error("FAILED: Timeout waiting for incoming call.")
            
        task_b.cancel()

if __name__ == "__main__":
    asyncio.run(run_scenario())
