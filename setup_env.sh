#!bin/bash

## set up your gamefile path.
export MAIN_DIR="$HOME/steam/l4d2/left4dead2"
echo "MAIN_DIR: $MAIN_DIR"
if [ ! -d $MAIN_DIR ]; then
  echo -e "\033[34m WARNING: Missing left4dead2 directory!"
fi

export STYX_DIR="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"
echo STYX_DIR: $STYX_DIR

export L4D2CR="$STYX_DIR/l4d2-competitive-rework"
echo L4D2-Competitive-Rework: $L4D2CR

if [ ! -d $L4D2CR ]; then
  echo "WARNING: Mising L4D2-Competitive-Rework directory!"
fi

export PLG_DIR="$MAIN_DIR/addons/sourcemod/plugins"

export SM_DIR="$L4D2CR/addons/sourcemod/scripting"

if [ ! -x $SM_DIR/spcomp ]; then
  echo  "WARNING: Missing sourcemod compiler."
else
  if [ "$temp_smdir" != "$SM_DIR" ]; then
    echo "Add $SM_DIR to PATH"
    export PATH=$SM_DIR:$PATH
    export temp_smdir=$SM_DIR
  fi
fi