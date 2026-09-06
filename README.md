一键安装命令:
bash <(curl -Ls https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/ins.sh) && bash <(curl -Ls https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/bp.sh) && /usr/bin/python3 -m pip install requests --break-system-packages && curl -o /root/browser-launcher.js -Ls  https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/browser-launcher.js && cp /root/browser-launcher.js /opt/browser-panel/server/runtime/browser-launcher.js


运行命令:
curl -o /root/panel.sh -Ls  https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/panel.sh && bash /root/panel.sh


运行在后台:
nohup bash /root/panel.sh > /dev/null 2>&1 &
