"""Choose the highest installed non-beta Xcode with an iOS 26+ SDK."""
import glob
import os
import re
import subprocess

choices = []
for app in glob.glob('/Applications/Xcode*.app'):
    if 'beta' in app.lower():
        continue
    env = dict(os.environ, DEVELOPER_DIR=f'{app}/Contents/Developer')
    result = subprocess.run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], env=env, capture_output=True, text=True)
    match = re.match(r'(\d+)\.(\d+)', result.stdout.strip())
    if result.returncode == 0 and match and int(match[1]) >= 26:
        choices.append((tuple(map(int, match.groups())), app))
if not choices:
    raise SystemExit('No stable Xcode with iOS 26+ SDK installed. Choose a newer macOS runner.')
_, app = max(choices)
subprocess.run(['sudo', 'xcode-select', '-s', f'{app}/Contents/Developer'], check=True)
print(f'Selected {app}')
