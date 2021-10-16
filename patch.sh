#!/bin/bash
MAIN_DIR="$HOME/steam/server/left4dead2"
MOD_ROOT="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"

echo $MAIN_DIR
cd $MAIN_DIR || fail "Missing $MAIN_DIR directory!"
rm -f styxupdate.zip
rm -rf temp            
echo "Making dir..."

mkdir temp
mkdir temp/addons
mkdir temp/addons/sourcemod
mkdir temp/cfg
mkdir temp/scripts
echo "copying addons/..."
cp addons/styxaddon.vpk temp/addons/
cp -r addons/sourcemod/plugins temp/addons/sourcemod/
cp -r addons/sourcemod/configs temp/addons/sourcemod/
cp -r addons/sourcemod/gamedata temp/addons/sourcemod/
rm -rf temp/addons/sourcemod/configs/geoip
rm -f temp/addons/sourcemod/configs/hostname.txt
echo "copying cfg/..."
cp -r cfg/cfgogl temp/cfg/
## cp -r cfg/stripper temp/cfg
## cp -r cfg/sourcemod temp/cfg/
## cp -r cfg/cfgs	temp/cfg/
cp cfg/server.cfg temp/cfg/
echo "copying vscripts..."
cp -r scripts/vscripts temp/scripts/
echo "copying others..."
cp motd.* temp/

cd temp/
echo "Zipping all files..."
zip -qur ../styxupdate.zip ./*

cd ../
echo "Remove temp files."
rm -rf temp

cd $MOD_ROOT

mv $MAIN_DIR/styxupdate.zip ./