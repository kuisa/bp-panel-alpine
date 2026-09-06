一键安装命令:
bash <(curl -Ls https://raw.githubusercontent.com/kuisa/bp-panel-alpine/refs/heads/main/install.sh) && bash <(curl -Ls https://raw.githubusercontent.com/kuisa/bp-panel-alpine/refs/heads/main/bp.sh) && /usr/bin/python3 -m pip install requests /usr/bin/python3 -m pip install requests && curl -o /root/browser-launcher.js -Ls  https://raw.githubusercontent.com/kuisa/bp-panel-alpine/refs/heads/main/browser-launcher.js && cp /root/browser-launcher.js /opt/browser-panel/server/runtime/browser-launcher.js


运行命令:
curl -o /root/panel.sh -Ls  https://raw.githubusercontent.com/kuisa/bp-panel-alpine/refs/heads/main/panel.sh && bash /root/panel.sh


运行在后台:
nohup bash /root/panel.sh > /dev/null 2>&1 &
