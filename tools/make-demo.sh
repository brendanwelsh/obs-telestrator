#!/usr/bin/env bash
# make-demo.sh — fully auto-produce the OBS showcase: launch OBS, build a demo
# scene, park a windowed projector off-screen-right, screen-record the OBS window
# (docks + preview) while driving a quick all-tools sequence, encode to a GIF.
set -u
ROOT="/c/Users/brend/Projects/streaming/telestrator"
cd "$ROOT" || exit 1
FFMPEG="C:/Users/brend/AppData/Local/Temp/ffmpeg/ffmpeg-8.1.1-essentials_build/bin/ffmpeg.exe"
OBS_EXE="C:/Program Files/obs-studio/bin/64bit/obs64.exe"
OBS_DIR="C:/Program Files/obs-studio/bin/64bit"

# ws password straight from OBS's local config — never hardcoded/committed
export OBS_WS_PASSWORD="$(node -e "const fs=require('fs');try{console.log(JSON.parse(fs.readFileSync(process.env.APPDATA+'/obs-studio/plugin_config/obs-websocket/config.json','utf8')).server_password||'')}catch(e){}")"

echo "== launch OBS if needed =="
cnt=$(powershell -NoProfile -Command '(Get-Process obs64 -ErrorAction SilentlyContinue|Measure-Object).Count' | tr -d '[:space:]')
if [ "${cnt:-0}" -lt 1 ]; then
	powershell -NoProfile -Command "Start-Process -FilePath '$OBS_EXE' -WorkingDirectory '$OBS_DIR' -ArgumentList '--multi','--disable-shutdown-check'" >/dev/null
	sleep 22
fi

echo "== wait for obs-websocket =="
for i in $(seq 1 12); do node tools/verify.mjs probe >/dev/null 2>&1 && { echo "ws up"; break; }; sleep 2; done

echo "== scene + projector =="
node tools/verify.mjs setup
node tools/verify.mjs projector
sleep 2

echo "== place windows (OBS left, projector parked right) =="
powershell -NoProfile -ExecutionPolicy Bypass -File tools/place-windows.ps1
sleep 1

echo "== record OBS region + drive all-tools sequence =="
"$FFMPEG" -y -f gdigrab -framerate 20 -offset_x 0 -offset_y 0 -video_size 1300x1040 -i desktop \
	-t 36 -pix_fmt yuv420p demo-raw.mp4 -loglevel error &
FF=$!
sleep 1.5
node tools/drive.mjs
wait $FF
echo "== recorded $(du -m demo-raw.mp4 2>/dev/null | cut -f1)MB =="

echo "== check frame (verify preview/docks captured, not black) =="
"$FFMPEG" -y -ss 12 -i demo-raw.mp4 -frames:v 1 -vf "scale=720:-1" demo-check.png -loglevel error && echo "check frame: demo-check.png"
