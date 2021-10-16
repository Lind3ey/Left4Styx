#!/bin/bash

L4D2="$HOME/steam/server/left4dead2"
PLUGINDIR="$L4D2/addons/sourcemod/plugins"
if [ ! -d "$L4D2" ]; then
    fail "Missing $L4D2 directory"
fi

if [ ! -d "$PLUGINDIR" ]; then
    mkdir -p $PLUGINDIR
fi
echo "L4D2: $L4D2"

cd scripting
echo "compiling plugins..."
make
echo "moving plugins..."
mkdir -p $PLUGINDIR/optional/styx
mv styx_compiled/* $PLUGINDIR/optional/styx/
cd ..

echo "copying addons to $L4D2"
cp ./addons $L4D2/ -r
echo "copying cfg to $L4D2"
cp ./cfg    $L4D2/ -r
echo "copying scripts to $L4D2"
cp ./scripts  $L4D2/ -r
echo "install complete"