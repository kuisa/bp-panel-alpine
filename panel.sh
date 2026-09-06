#!/bin/bash

APP=/opt/browser-panel

echo "[BP] starting Xvfb..."

pkill -f '[X]vfb :1' 2>/dev/null

/usr/bin/Xvfb :1 \
-screen 0 1440x900x24 \
-ac \
+extension GLX \
+render \
-noreset \
>>$APP/logs/xvfb.log 2>&1 &


sleep 2


echo "[BP] starting panel..."

cd $APP


export NODE_ENV=production
export DISPLAY=:1.0


nohup /usr/bin/node server/index.js \
>>$APP/logs/panel.log 2>&1 &


echo "[BP] started"
echo "http://0.0.0.0:3210"