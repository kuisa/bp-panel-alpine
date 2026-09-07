#!/bin/sh

apk add \
python3 \
py3-pip \
firefox \
geckodriver \
gtk+3.0 \
fontconfig \
ttf-dejavu \
dbus \
mesa-gl \
nss \
libx11 \
libxcomposite \
libxdamage \
libxrandr \
libxtst

pip3 install ruyipage --break-system-packages

echo "========================================"
echo " Installation finished"
echo "========================================"
echo
