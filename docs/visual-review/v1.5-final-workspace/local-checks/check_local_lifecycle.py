"""Additive local QA lifecycle check using the existing running processor.
Only this run's new monthly Setup is edited; no database/state injection.
Credentials/tokens stay in memory. Natural activation has a bounded wait.
Usage: python3 check_local_lifecycle.py /protected/qa-creds.json /tmp/result.json
"""
import datetime, json, stat, sys, time, urllib.request, urllib.error, uuid
from pathlib import Path

def main():
    path, output = map(Path, sys.argv[1:3])
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    c = json.loads(path.read_text()); assert c['gateway'] == 'http://127.0.0.1:30080/api/v1'
    def api(method, route, body=None, token=None):
        r = urllib.request.Request(c['gateway'] + route, method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer ' + token} if token else {})})
        try:
            with urllib.request.urlopen(r, timeout=10) as v: return v.status, json.load(v)
        except urllib.error.HTTPError as e: return e.code, {}
    s, login = api('POST', '/auth/login', c['accounts']['b']); assert s == 200
    token = login['tokens']['access_token']
    s, candles = api('GET', f"/chart/symbols/{c['symbol_id']}/candles?timeframe=1m&limit=3", token=token); assert s == 200
    candle = sorted(candles['candles'], key=lambda x: x['timestamp'])[-2]
    entry = candle['close']
    run = 'phaseb-lifecycle-' + uuid.uuid4().hex[:8]
    body = {'symbol_id': c['symbol_id'], 'timeframe': '1M', 'intent': 'setup', 'visibility': 'guild',
            'title': run, 'note': 'Local natural processor activation check', 'tracking_enabled': True,
            'components': [{'component_type': 'anchor', 'payload': {'time': candle['timestamp'], 'price': entry}},
                           {'component_type': 'level.entry', 'payload': {'price': entry}},
                           {'component_type': 'level.sl', 'payload': {'price': entry * 0.8}},
                           {'component_type': 'level.tp', 'payload': {'price': entry * 1.2}}]}
    root = f"/chart/guilds/{c['guild_id']}/markers"
    s, saved = api('POST', root, body, token); assert s in [200, 201], 'Monthly QA Setup unavailable'
    mid = saved['id']; result = {'run': run, 'created_marker_id': mid, 'gateway': c['gateway'],
        'coverage': 'REST and existing processor only; no signed-in UI or forced lifecycle state',
        'states': [saved.get('tracking_state')], 'checks': [{'check': 'tracked Setup create', 'pass': True}]}
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'run': run, 'created_marker_id': mid}), flush=True)
    deadline = time.monotonic() + 50
    current = saved
    while current.get('tracking_state') == 'ARMED' and time.monotonic() < deadline:
        time.sleep(3)
        s, current = api('GET', '/chart/markers/' + mid, token=token); assert s == 200
        if current.get('tracking_state') != result['states'][-1]: result['states'].append(current.get('tracking_state'))
    if current.get('tracking_state') != 'ACTIVE':
        result['manual_gate'] = 'Natural ACTIVE transition was not observed during bounded wait; do not force state or restart stack.'
    else:
        result['checks'].append({'check': 'existing processor naturally activates saved Setup', 'pass': True})
        components = [{'component_type': x['component_type'], 'payload': x['payload']} for x in current['components']]
        s, _ = api('PUT', root + '/' + mid, {'components': components}, token)
        assert s == 400, 'Activated component update was not refused'
        result['checks'].append({'check': 'ACTIVE component edits rejected, including identical geometry', 'pass': True, 'status': s})
        s, edited = api('PUT', root + '/' + mid, {'note': 'Local ACTIVE note-only edit'}, token); assert s == 200
        assert edited['components'] == current['components'], 'Note-only edit changed saved geometry'
        result['checks'].append({'check': 'ACTIVE note-only update preserves exact components', 'pass': True})
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'run': run, 'states': result['states'], 'checks_passed': len(result['checks']), 'manual_gate': result.get('manual_gate')}))

if __name__ == '__main__':
    try: main()
    except Exception as e:
        print('Local lifecycle check failed:', type(e).__name__)
        sys.exit(1)
