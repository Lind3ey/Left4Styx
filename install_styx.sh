#!/bin/bash

if [ $MAIN_DIR ]; then
	if [ ! -d "$MAIN_DIR" ]; then
    echo "Missing $MAIN_DIR directory"
	  exit 9
	fi
	echo "L4D2: $MAIN_DIR"
else 
  echo "Please setup enviroment first."
  exit 9
fi

if [ $PLG_DIR ]; then
	if [ ! -d "$PLG_DIR" ]; then
  	echo mkdir:$PLG_DIR
  	mkdir -p $PLG_DIR
	fi
else
	echo "Please setup enviriment first."
	exit 8
fi

cd scripting/
echo "compiling plugins..."
make
echo "moving plugins..."
mkdir -p $PLG_DIR/optional/styx
mv styx_compiled/* $PLG_DIR/optional/styx/
cd ..

echo "copying addons to $MAIN_DIR"
cp ./addons $MAIN_DIR/ -r
echo "copying cfg to $MAIN_DIR"
cp ./cfg    $MAIN_DIR/ -r
echo "copying scripts to $MAIN_DIR"
cp ./scripts  $MAIN_DIR/ -r
echo "install complete"