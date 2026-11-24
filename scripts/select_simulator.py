import json
import os
import re
import subprocess

payload = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
choices = []
for runtime, devices in payload['devices'].items():
    match = re.search(r'iOS-(\d+)-(\d+)', runtime)
    if not match or int(match[1]) < 26:
        continue
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            choices.append((tuple(map(int, match.groups())), device['name'], device['udid']))
if not choices:
    raise SystemExit('No available iPhone simulator with iOS 26+. Install a simulator runtime.')
_, name, udid = max(choices)
print(f'Using {name} ({udid})')
with open(os.environ['GITHUB_ENV'], 'a') as output:
    output.write(f'MUSICAPP_SIMULATOR_ID={udid}\n')
