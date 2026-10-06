#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.6.2
mkdir -p .ci-tools/godot .ci-tools/templates
if [ ! -x .ci-tools/godot/godot ]; then
  curl --fail --location --retry 3 -o .ci-tools/godot.zip "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip"
  unzip -qo .ci-tools/godot.zip -d .ci-tools/godot
  mv .ci-tools/godot/Godot* .ci-tools/godot/godot
  chmod +x .ci-tools/godot/godot
fi
.ci-tools/godot/godot --headless --version
echo '5a806b2b385279d9607094d33e946ed828e9606df4cb46d258ca27468dc5c1c9  .ci-tools/godot/godot' | sha256sum --check
if [ ! -f .ci-tools/templates/templates/android_debug.apk ]; then
  curl --fail --location --retry 3 -o .ci-tools/templates.zip "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz"
  unzip -qo .ci-tools/templates.zip 'templates/android_debug.apk' 'templates/android_release.apk' -d .ci-tools/templates
fi
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
mkdir -p "$template_dir"
cp .ci-tools/templates/templates/android*.apk "$template_dir/"
mkdir -p .ci-tools/keys build
if [ ! -f .ci-tools/keys/debug.keystore ]; then
  keytool -genkeypair -keystore .ci-tools/keys/debug.keystore -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
fi
python3 - <<'PY'
from pathlib import Path
import os
root=Path.cwd()
config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'godot'
config.mkdir(parents=True,exist_ok=True)
sdk=os.environ.get('ANDROID_HOME',os.environ.get('ANDROID_SDK_ROOT',''))
java=os.environ.get('JAVA_HOME','/usr/lib/jvm/java-17-openjdk-amd64')
key=str(root/'.ci-tools/keys/debug.keystore')
(config/'editor_settings-4.6.tres').write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'+f'export/android/android_sdk_path = "{sdk}"\nexport/android/java_sdk_path = "{java}"\nexport/android/debug_keystore = "{key}"\nexport/android/debug_keystore_user = "androiddebugkey"\nexport/android/debug_keystore_pass = "android"\n')
PY
