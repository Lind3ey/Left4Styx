#!/bin/bash
UPDATE=./Dev/xyts-2d4l/styxupdate.zip
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