#!/bin/bash

L4D2="$HOME/steam/server/left4dead2"
PLUGINDIR="$L4D2/addons/sourcemod/plugins"

echo "L4D2: $L4D2"

cd scripting
echo "compiling plugins..."
make
echo "moving plugins..."
mkdir -p $PLUGINDIR/optional/styx
mv styx_compiled/* $PLUGINDIR/optional/styx/
cd ..

echo "moving addons to $L4D2"
cp ./addons $L4D2/ -r
echo "moving cfg to $L4D2"
cp ./cfg    $L4D2/ -r
echo "moving scripts to $L4D2"
cp ./scripts  $L4D2/ -r