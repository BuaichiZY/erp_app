"""Run the pure Java regression checks without an Android device or SDK."""
import os
from pathlib import Path
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
EXE = '.exe' if os.name == 'nt' else ''
jdk = os.environ.get('ERP_JAVA_HOME') or os.environ.get('JAVA_HOME')
javac = str(Path(jdk) / 'bin' / ('javac' + EXE)) if jdk else shutil.which('javac')
java = str(Path(jdk) / 'bin' / ('java' + EXE)) if jdk else shutil.which('java')
if not javac or not java or not Path(javac).exists() or not Path(java).exists():
    raise SystemExit('Install JDK 17 and set JAVA_HOME.')
output = ROOT / 'build' / 'tests'
output.mkdir(parents=True, exist_ok=True)
names = ('CameraPreviewGeometry', 'ChatPresentation', 'DiscoverFilters', 'EnergyTime', 'LikesRules',
         'PostRules', 'ProfileText', 'PullRefreshGesture', 'ReactionRules',
         'ReadResponseCache', 'ImageSizing', 'ReadRefreshBatch', 'SwipeGesturePolicy', 'ThemePalette', 'WebSocketFrames',
         'LanguageRules', 'UiStrings', 'ReleaseVersion', 'ReleaseAssetPolicy', 'ChatImagePolicy')
sources = [ROOT / 'src' / 'sex' / 'erp' / 'android' / (name + '.java') for name in names]
tests = sorted(test for test in (ROOT / 'tests').glob('*Test.java') if test.stem != 'QrRoundTripTest')
subprocess.run([javac, '-encoding', 'UTF-8', '--release', '8', '-d', str(output),
                *map(str, sources + tests)], check=True)
for test in tests:
    subprocess.run([java, '-cp', str(output), 'sex.erp.android.' + test.stem], check=True)

qr_sources=sorted((ROOT / 'src' / 'io' / 'nayuki' / 'qrcodegen').glob('*.java'))
zxing=ROOT / 'third_party' / 'zxing-core-3.5.3.jar'
subprocess.run([javac, '-encoding', 'UTF-8', '--release', '8', '-cp', str(zxing),
                '-d', str(output), *map(str, qr_sources), str(ROOT / 'tests' / 'QrRoundTripTest.java')], check=True)
subprocess.run([java, '-cp', str(output) + os.pathsep + str(zxing),
                'sex.erp.android.QrRoundTripTest'], check=True)

literal = re.compile(r'"((?:\\.|[^"\\])*)"')
authored=set()
for source in (ROOT / 'src').rglob('*.java'):
    if source.name in {'LanguageRules.java', 'UiStrings.java', 'AppLanguage.java'}:
        continue
    for match in literal.finditer(source.read_text(encoding='utf-8')):
        if re.search(r'[\u3400-\u9fff]', match.group(1)):
            authored.add(json.loads(match.group()))
for language in ('en', 'ja', 'ko', 'zh_hant'):
    translations=json.loads((ROOT / 'res' / 'raw' / ('ui_' + language + '.json')).read_text(encoding='utf-8'))
    missing=authored-translations.keys()
    if missing:
        raise AssertionError(f'{language}: untranslated interface literals: {sorted(missing)[:8]}')
    print(f'{language}: {len(authored)} interface literals covered')
