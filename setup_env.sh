#!bin/bash

export STYX_DIR="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"
echo STYX_DIR: $STYX_DIR

## set up your copy path.
export LCR="$HOME/Dev/L4D2-Competitive-Rework"
echo L4D2-Competitive-Rework: $LCR

if [ ! -d $LCR ]; then
  echo "WARNING: Mising L4D2-Competitive-Rework directory!"
fi

export MAIN_DIR="$HOME/steam/server/left4dead2"
echo "MAIN_DIR: $MAIN_DIR"
if [ ! -d $MAIN_DIR ]; then
  echo "WARNING: Missing left4dead2 directory!"
fi

export PLG_DIR="$MAIN_DIR/addons/sourcemod/plugins"

export SM_DIR="$LCR/addons/sourcemod/scripting"

if [ ! -x $SM_DIR/spcomp ]; then
  echo  "WARNING: Missing sourcemod compiler."
else
  if [ "$temp_smdir" != "$SM_DIR" ]; then
    echo "Add $SM_DIR to PATH"
    export PATH=$SM_DIR:$PATH
    export temp_smdir=$SM_DIR
  fi
fi