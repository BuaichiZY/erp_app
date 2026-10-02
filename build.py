"""Build a signed, standalone APK using the official Android SDK tools."""
import hashlib
import os
import pathlib
import re
import secrets
import shutil
import subprocess
import zipfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
LEGACY_SDK = ROOT.parent / 'erp-android' / 'tools'
sdk_setting = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
SDK_ROOT = pathlib.Path(sdk_setting) if sdk_setting else LEGACY_SDK
EXE = '.exe' if os.name == 'nt' else ''
TOOLS = SDK_ROOT / 'build-tools' / os.environ.get('ERP_BUILD_TOOLS', '35.0.0')
if not (TOOLS / ('aapt2' + EXE)).exists():
    candidates = list((SDK_ROOT / 'build-tools').glob('*/aapt2' + EXE))
    if not candidates:
        raise SystemExit('Install Android SDK Build-Tools and set ANDROID_SDK_ROOT.')
    TOOLS = max(candidates, key=lambda p: tuple(int(x) for x in re.findall(r'\d+', p.parent.name))).parent
platforms = SDK_ROOT / ('platforms' if (SDK_ROOT / 'platforms').exists() else 'platform')
ANDROID = platforms / 'android-35' / 'android.jar'
ZXING = ROOT / 'third_party' / 'zxing-core-3.5.3.jar'
if not ANDROID.exists():
    raise SystemExit('Install Android SDK Platform android-35.')
jdk_setting = os.environ.get('ERP_JAVA_HOME') or os.environ.get('JAVA_HOME')
if not jdk_setting:
    javac = shutil.which('javac')
    jdk_setting = str(pathlib.Path(javac).resolve().parent.parent) if javac else r'C:\Program Files\Java\jdk-17'
JAVA_HOME = pathlib.Path(jdk_setting)
JAVA = JAVA_HOME / 'bin' / ('java' + EXE)
if not JAVA.exists() or not (JAVA_HOME / 'bin' / ('javac' + EXE)).exists():
    raise SystemExit('Set ERP_JAVA_HOME or JAVA_HOME to an installed JDK 17 directory.')
env = dict(os.environ)

def run(args):
    print('Running ' + pathlib.Path(str(args[0])).name, flush=True)
    subprocess.run([str(x) for x in args], check=True, cwd=ROOT, env=env)

run([TOOLS / ('aapt2' + EXE), 'compile', '--dir', ROOT / 'res', '-o', BUILD / 'resources.zip'])
run([TOOLS / ('aapt2' + EXE), 'link', '-o', BUILD / 'base.apk', '-I', ANDROID,
     '--manifest', ROOT / 'AndroidManifest.xml', BUILD / 'resources.zip'])
classes = BUILD / 'classes'
classes.mkdir(exist_ok=True)
# Exclude classes removed from the source tree when rebuilding an existing checkout.
for stale in classes.rglob('*.class'):
    stale.resolve().relative_to(BUILD.resolve())
    stale.unlink()
run([JAVA_HOME / 'bin' / ('javac' + EXE), '-encoding', 'UTF-8', '--release', '8',
     '-classpath', str(ANDROID) + os.pathsep + str(ZXING), '-d', classes, *sorted((ROOT / 'src').rglob('*.java'))])
with zipfile.ZipFile(BUILD / 'classes.jar', 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in classes.rglob('*.class'):
        archive.write(file, file.relative_to(classes).as_posix())
dex = BUILD / 'dex'
dex.mkdir(exist_ok=True)
run([JAVA, '-cp', TOOLS / 'lib' / 'd8.jar', 'com.android.tools.r8.D8', '--release',
     '--min-api', '26', '--lib', ANDROID, '--output', dex, BUILD / 'classes.jar', ZXING])
with zipfile.ZipFile(BUILD / 'base.apk', 'a', zipfile.ZIP_DEFLATED) as archive:
    archive.write(dex / 'classes.dex', 'classes.dex')
run([TOOLS / ('zipalign' + EXE), '-f', '4', BUILD / 'base.apk', BUILD / 'aligned.apk'])
legacy_signing = ROOT.parent / 'erp-android' / 'signing'
signing = pathlib.Path(os.environ.get('ERP_SIGNING_DIR', str(legacy_signing if legacy_signing.exists() else ROOT / '.signing')))
signing.mkdir(exist_ok=True)
password_file = signing / 'password.txt'
keystore = signing / 'release.p12'
if not password_file.exists():
    password_file.write_text(secrets.token_urlsafe(36), encoding='utf-8')
env['ERP_SIGN_PASSWORD'] = password_file.read_text(encoding='utf-8').strip()
if not keystore.exists():
    run([JAVA_HOME / 'bin' / ('keytool' + EXE), '-genkeypair', '-keystore', keystore,
         '-storetype', 'PKCS12', '-storepass:env', 'ERP_SIGN_PASSWORD',
         '-alias', 'erp-release', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
         '-dname', 'CN=ERP Personal Android, O=Personal, C=CN'])
manifest = ET.parse(ROOT / 'AndroidManifest.xml').getroot()
version = manifest.attrib['{http://schemas.android.com/apk/res/android}versionName']
output = pathlib.Path(os.environ.get('ERP_OUTPUT_DIR', str(ROOT.parent if LEGACY_SDK.exists() else ROOT / 'dist')))
output.mkdir(parents=True, exist_ok=True)
apk = output / ('ERP-Native-' + version + '.apk')
run([JAVA, '-jar', TOOLS / 'lib' / 'apksigner.jar', 'sign', '--ks', keystore,
     '--ks-key-alias', 'erp-release', '--ks-pass', 'env:ERP_SIGN_PASSWORD', '--out', apk, BUILD / 'aligned.apk'])
run([JAVA, '-jar', TOOLS / 'lib' / 'apksigner.jar', 'verify', '--verbose', '--print-certs', apk])
run([TOOLS / ('zipalign' + EXE), '-c', '4', apk])
run([TOOLS / ('aapt2' + EXE), 'dump', 'badging', apk])
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
(output / (apk.name + '.sha256')).write_text(digest + '  ' + apk.name + '\n', encoding='utf-8')
print('APK ready: ' + str(apk), flush=True)
print('Size: ' + str(apk.stat().st_size) + ' bytes', flush=True)
