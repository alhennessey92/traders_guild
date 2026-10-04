"""Additive local QA REST/WebSocket contract check. No auth changes or cleanup.
Usage: python3 check_local_realtime.py /protected/qa-creds.json /tmp/result.json
Credentials and tokens stay in memory; output contains only QA IDs/check results.
API/WebSocket checks are not signed-in chart/workspace UI coverage.
"""
import base64, hashlib, json, os, socket, stat, struct, subprocess, sys, time
import urllib.request, urllib.error, uuid, traceback
from pathlib import Path


def main():
    creds_path, output = map(Path, sys.argv[1:3])
    assert stat.S_IMODE(creds_path.stat().st_mode) == 0o600, 'Protected credentials required'
    c = json.loads(creds_path.read_text())
    assert c['gateway'] == 'http://127.0.0.1:30080/api/v1', 'Loopback gateway required'
    checks = []
    disabled = ['DISCORD_WEBHOOKS_ENABLED', 'DISCORD_MARKER_AUTOPOST_ENABLED', 'DISCORD_RESULT_POSTBACK_ENABLED',
                'GUILD_DIGEST_ENABLED', 'REGISTRATION_ALERTS_ENABLED', 'FCM_ENABLED', 'AWARDS_ENABLED',
                'AWARD_PROCESSOR_ENABLED', 'AWARD_NOTIFICATIONS_ENABLED']
    for service in ['auth', 'core', 'chart', 'realtime', 'reputation']:
        obj = json.loads(subprocess.check_output(['docker', 'inspect', f'traders-guild-local-{service}-service-1']))[0]
        env = dict(x.split('=', 1) for x in obj['Config']['Env'] if '=' in x)
        assert all(env[k].lower() == 'false' for k in disabled if k in env), 'Outbound flag enabled'
        assert not any(env.get(k) for k in ['RESEND_API_KEY', 'APNS_KEY_ID', 'APNS_KEY_PATH', 'FCM_CREDENTIALS_PATH']), 'Outbound config present'
    def api(method, path, body=None, token=None):
        req = urllib.request.Request(c['gateway'] + path, method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer ' + token} if token else {})})
        try:
            with urllib.request.urlopen(req, timeout=15) as r: return r.status, json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e: return e.code, {}  # never dump auth/body
    tokens = {}
    for role in ['a', 'b']:
        status, body = api('POST', '/auth/login', c['accounts'][role])
        assert status == 200, 'Local QA authentication failed'
        tokens[role] = body['tokens']['access_token']
    channel = f"guild:{c['guild_id']}:markers"
    class WS:
        def __init__(self):
            self.sock = socket.create_connection(('127.0.0.1', 30080), timeout=15)
            self.buffer = b''
            key = base64.b64encode(os.urandom(16)).decode()
            request = (f"GET /ws/messaging?token={tokens['b']} HTTP/1.1\r\nHost: 127.0.0.1:30080\r\n"
                       f"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
            self.sock.sendall(request.encode())
            while b'\r\n\r\n' not in self.buffer: self.buffer += self.sock.recv(4096)
            header, self.buffer = self.buffer.split(b'\r\n\r\n', 1)
            assert header.startswith(b'HTTP/1.1 101'), 'WebSocket upgrade failed'
            expected = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
            assert expected in header, 'Invalid upgrade accept'
            self.send(json.dumps({'type': 'subscribe', 'channels': [channel]}).encode())
            self.until(lambda x: x.get('type') == 'subscribed' and channel in x.get('channels', []))
        def send(self, data, opcode=1):
            mask = os.urandom(4); size = len(data)
            header = bytes([0x80 | opcode, 0x80 | size]) if size < 126 else bytes([0x80 | opcode, 0x80 | 126]) + struct.pack('!H', size)
            self.sock.sendall(header + mask + bytes(v ^ mask[i % 4] for i, v in enumerate(data)))
        def read(self, n):
            while len(self.buffer) < n:
                chunk = self.sock.recv(4096)
                if not chunk: raise ConnectionError('Local socket closed')
                self.buffer += chunk
            data, self.buffer = self.buffer[:n], self.buffer[n:]; return data
        def until(self, predicate):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                self.sock.settimeout(max(0.1, deadline - time.monotonic()))
                a, b = self.read(2); opcode = a & 15; size = b & 127
                if size == 126: size = struct.unpack('!H', self.read(2))[0]
                elif size == 127: size = struct.unpack('!Q', self.read(8))[0]
                assert size < 2_000_000 and not b & 128, 'Invalid server frame'
                data = self.read(size)
                if opcode == 9: self.send(data, 10); continue
                if opcode == 8: raise ConnectionError('Local socket closed')
                if opcode == 1:
                    value = json.loads(data)
                    if predicate(value): return value
            raise TimeoutError('Expected local event absent')
        def close(self):
            self.send(struct.pack('!H', 1000), 8); self.sock.close()
    ws = WS()
    s, candles = api('GET', f"/chart/symbols/{c['symbol_id']}/candles?timeframe=1w&limit=2", token=tokens['a'])
    assert s == 200 and candles['candles']
    candle = candles['candles'][-1]
    run = 'phaseb-ws-' + uuid.uuid4().hex[:8]
    body = {'symbol_id': c['symbol_id'], 'timeframe': '1w', 'intent': 'analysis', 'visibility': 'guild',
            'title': run, 'note': 'Local realtime drawing check', 'tracking_enabled': False,
            'components': [{'component_type': 'anchor', 'payload': {'time': candle['timestamp'], 'price': candle['close']}},
                           {'component_type': 'drawing.horizontal_line', 'payload': {'price': candle['close'] + 100, 'label': 'Local drawing', 'future_qa': {'keep': True}}}]}
    marker_path = f"/chart/guilds/{c['guild_id']}/markers"
    s, saved = api('POST', marker_path, body, tokens['a'])
    assert s in [200, 201], 'Local drawing create failed'
    marker_id = saved['id']
    print(json.dumps({'run': run, 'created_marker_id': marker_id}), flush=True)
    def event(kind):
        value = ws.until(lambda x: x.get('type') == kind and (x.get('payload') or {}).get('id') == marker_id)
        checks.append({'check': kind, 'pass': True, 'marker_id': marker_id, 'channel': value.get('channel')})
    event('marker_created')
    s, edited = api('PUT', marker_path + '/' + marker_id, {'note': 'Local realtime edited'}, tokens['a'])
    assert s == 200, 'Local drawing edit failed'
    event('marker_updated')
    s, reread = api('GET', '/chart/markers/' + marker_id, token=tokens['a'])
    assert s == 200 and reread['components'][1]['payload'] == saved['components'][1]['payload'], 'Saved drawing changed'
    checks.append({'check': 'drawing REST read/edit preserves normalized saved payload', 'pass': True})
    backend_limits = {'unknown_extra_keys_preserved_at_create': 'future_qa' in saved['components'][1]['payload']}
    assert not backend_limits['unknown_extra_keys_preserved_at_create'], 'Recheck existing normalization behavior'
    ws.close(); ws = WS()
    s, edited = api('PUT', marker_path + '/' + marker_id, {'note': 'Local reconnect refresh'}, tokens['a'])
    assert s == 200
    event('marker_updated')
    checks[-1]['check'] = 'reconnect/resubscribe marker_updated'
    ws.close()
    bad_question = dict(body, intent='question', note='short', components=body['components'][:1])
    s, _ = api('POST', marker_path, bad_question, tokens['a'])
    assert s in [400, 422], 'Short Question unexpectedly accepted'
    checks.append({'check': 'server rejects short Question without creating a marker', 'pass': True, 'status': s})
    result = {'coverage': 'REST/WebSocket contracts only; no signed-in workspace/chart UI coverage',
              'gateway': c['gateway'], 'run': run, 'backend_limits': backend_limits, 'created_marker_ids': [marker_id], 'checks': checks}
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'run': run, 'checks_passed': len(checks), 'created_marker_ids': [marker_id]}))

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('Local QA check failed:', type(error).__name__, [(f.name, f.lineno) for f in traceback.extract_tb(error.__traceback__)])  # no credentials, URL or response dump
        sys.exit(1)
