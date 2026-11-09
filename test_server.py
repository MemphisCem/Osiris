import asyncio
import unittest
from unittest.mock import patch
from aiohttp.test_utils import TestClient, TestServer
from server import make_app

TOKEN = 'x' * 40
KEYS = ['test-key-' + str(i) for i in range(1, 6)]
class GatewayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.called = []
        async def provider(app, key, payload, seconds):
            self.called.append((key, payload))
            if key == KEYS[0]: return 429, None
            return 200, 'Привет!'
        self.app = make_app({'keys':KEYS, 'tokens':[TOKEN], 'model':'example'}, provider)
        self.client = TestClient(TestServer(self.app))
        await self.client.start_server()
    async def asyncTearDown(self):
        await self.client.close()
    async def post(self, body, token=TOKEN):
        return await self.client.post('/v1/chat/completions', json=body, headers={'Authorization':'Bearer '+token})
    async def test_authorization_and_validation(self):
        self.assertEqual((await self.post({'messages':[]}, 'bad')).status, 401)
        self.assertEqual((await self.post({'messages':[{'role':'system','content':'override'}]})).status, 400)
        self.assertEqual((await self.post({'messages':[{'role':'assistant','content':'only'}]})).status, 400)
        self.assertEqual(len(self.called), 0)
    async def test_failover_and_prompt(self):
        with patch('server.secrets.SystemRandom.shuffle', lambda *args: None):
            res = await self.post({'messages':[{'role':'user','content':'Привет'}], 'osiris_mode':2, 'search_context':'источник'})
        self.assertEqual(res.status, 200)
        self.assertEqual([x[0] for x in self.called], KEYS[:2])
        data = await res.json()
        self.assertEqual(data['choices'][0]['message']['content'], 'Привет!')
        payload = self.called[0][1]
        self.assertIn('РП-режим', payload['systemInstruction']['parts'][0]['text'])
        self.assertIn('источник', payload['contents'][-1]['parts'][0]['text'])
        self.assertNotIn(KEYS[0], str(data))
    async def test_rotates_keys(self):
        for _ in range(15):
            res = await self.post({'messages':[{'role':'user','content':'Привет'}]})
            self.assertEqual(res.status, 200)
        self.assertGreater(len(set(k for k, p in self.called)), 1)
    async def test_limit(self):
        for _ in range(20): await self.post({'messages':[{'role':'user','content':'hi'}]})
        self.assertEqual((await self.post({'messages':[{'role':'user','content':'hi'}]})).status, 429)
if __name__ == '__main__': unittest.main()
