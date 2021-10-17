#!/bin/bash
if [ $MAIN_DIR ]; then
  echo $MAIN_DIR
else
  echo "Setup env first."
  exit 1
fi

cd $MAIN_DIR || exit "Missing $MAIN_DIR directory!"

echo check temp files...
rm -f styxupdate.zip
rm -rf temp

echo "Making dir..."
mkdir temp -p
mkdir temp/addons -p
mkdir temp/addons/sourcemod -p
mkdir temp/cfg -p
mkdir temp/scripts -p

echo "copying addons/..."
cp addons/styxaddon.vpk temp/addons/
cp -r addons/sourcemod/plugins temp/addons/sourcemod/
cp -r addons/sourcemod/configs temp/addons/sourcemod/
cp -r addons/sourcemod/gamedata temp/addons/sourcemod/

echo remove excess files...
rm -rf temp/addons/sourcemod/configs/geoip
rm -f temp/addons/sourcemod/configs/hostname.txt

echo "copying cfg/..."
cp -r cfg/cfgogl temp/cfg/
cp cfg/server.cfg temp/cfg/

echo "copying vscripts..."
cp -r scripts/vscripts/*styx* temp/scripts/

echo "copying others..."
cp motd.* temp/

cd temp/
echo "Zipping all files..."
zip -qury ../styxupdate.zip ./*

cd ../
echo "Remove temp files."
rm -rf temp

cd $STYX_DIR

mv $MAIN_DIR/styxupdate.zip ./