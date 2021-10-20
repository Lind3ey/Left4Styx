#!/bin/bash

if [ ! $MAIN_DIR ] || [ ! -d "$MAIN_DIR" ]; then
    echo -e "$r Missing $MAIN_DIR directory$o"
	return 1 || exit 1
fi

if [ $PLG_DIR ]; then
	if [ ! -d "$PLG_DIR" ]; then
  	echo -e "$y Making dir $PLG_DIR $o"
  	mkdir -p $PLG_DIR
	fi
else
	echo -e "$r Please setup enviriment first.$o"
	return 8 || exit 8
fi

cd coding/
echo -e "$b Compiling plugins...$o"
make
echo -e "$b moving plugins...$o"
mkdir -p $PLG_DIR/optional/styx
mv compiled/* $PLG_DIR/optional/styx/
cd ..

echo "copying addons to $MAIN_DIR"
cp ./addons $MAIN_DIR/ -r
echo "copying cfg to $MAIN_DIR"
cp ./cfg    $MAIN_DIR/ -r
echo "copying scripts to $MAIN_DIR"
cp ./scripts  $MAIN_DIR/ -r
echo -e "$y Install complete$o"

if [ -d ./custom ]; then
  cp ./custom/* -r $MAIN_DIR/
fi 

namefile=$MAIN_DIR/addons/sourcemod/configs/hostname.txt

if [ ! -f $namefile ]; then
	read -p "Enter short hostname: "
	NAMESHORT=$REPLY
	read -p "Enter long hostname : "
	NAMELONG=$REPLY

	[ ! $NAMESHORT ] && NAMESHORT="$HOSTNAME"
	[ ! $NAMELONG ] && NAMELONG="$HOSTNAME"

	echo -e "$NAMESHORT\n$NAMELONG" > $namefile
fi
