"""Package an unsigned device .app and verify the installable Payload layout."""
import pathlib
import plistlib
import stat
import sys
import zipfile

app, output = map(pathlib.Path, sys.argv[1:])
if not app.is_dir() or app.suffix != '.app':
    raise SystemExit('Expected an existing .app directory')
with (app / 'Info.plist').open('rb') as handle:
    info = plistlib.load(handle)
executable = app / info['CFBundleExecutable']
if not executable.is_file():
    raise SystemExit('App executable is missing')
if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
    raise SystemExit('Refusing to package a simulator build as an IPA')
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file():
            archive.write(file, pathlib.Path('Payload') / app.name / file.relative_to(app))
with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise SystemExit('IPA failed CRC validation')
    binary = archive.getinfo(f'Payload/{app.name}/{executable.name}')
    if not (binary.external_attr >> 16) & stat.S_IXUSR:
        raise SystemExit('App executable lost executable permissions')
print(f'Created {output} ({output.stat().st_size:,} bytes); unsigned, device build')
