#!/bin/bash
## the patch address at your coding server, begin at $HOME
UPDATE=./dev/left4styx/styxupdate.zip
## the left4dead2 folder in your running server.
L4D2_DIR=$HOME/steam/l4d2/left4dead2

if [ ! -d $L4D2_DIR ]; then
  echo "Missing $L4D2_DIR directory!"
  exit 9
fi

echo connecting to pluma server...
## sftp host server
sftp pluma << EOF
  get "$UPDATE" "$L4D2_DIR/"
  exit
EOF

echo go to left4dead2 folder and unzip file.
cd $L4D2_DIR
unzip -qou styxupdate.zip
echo unpdate complete.