#!/usr/bin/env bash
set -euo pipefail
pkg=io.github.atlasru.ironveil
adb logcat -c
adb install -r build/IRON_VEIL_0.1.0.apk
adb shell wm size 720x1280
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb shell am start -W -n "$pkg/org.godotengine.godot.GodotApp"
sleep 8
adb shell pidof "$pkg"
adb exec-out screencap -p > build/android-menu.png
adb shell input tap 250 250
sleep 5
adb exec-out screencap -p > build/android-third-person.png
adb shell input swipe 145 580 145 480 900
adb shell input swipe 850 380 1020 380 450
adb shell input tap 1136 52
sleep 2
adb exec-out screencap -p > build/android-first-person.png
adb shell input tap 1160 512
adb shell input keyevent 3
sleep 2
adb shell am start -W -n "$pkg/org.godotengine.godot.GodotApp"
sleep 3
adb exec-out screencap -p > build/android-resume.png
adb shell pidof "$pkg"
adb logcat -d > build/android-logcat.txt
if rg 'FATAL EXCEPTION|SCRIPT ERROR|Fatal signal' build/android-logcat.txt; then exit 1; fi
echo 'Android install / launch / touch movement / perspective / background-resume passed.'
