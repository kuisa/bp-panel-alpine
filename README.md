一键安装运行命令:
bash <(curl -Ls 'https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/ins.sh') && bash <(curl -Ls 'https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/bp.sh') && (pkill -f 'node server/index.js' 2>/dev/null || true); curl -fLs "https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/browser-launcher.js" -o /root/browser-launcher.js && cp /root/browser-launcher.js /opt/browser-panel/server/runtime/browser-launcher.js && nohup node /opt/browser-panel/server/index.js >/dev/null 2>&1 &


运行命令:
curl -o /root/panel.sh -Ls  https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/panel.sh && bash /root/panel.sh


运行在后台:
nohup bash /root/panel.sh > /dev/null 2>&1 &


一键安装firefox和ruyipage:
bash <(curl -Ls 'https://raw.githubusercontent.com/kuisa/bp-panel-alpine/main/ff.sh')
