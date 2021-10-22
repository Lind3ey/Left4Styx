#!/bin/bash
## set up your gamefile path.
export MAIN_DIR="$HOME/steam/l4d2/left4dead2"

#### color vars. ##############################
export r='\033[31m' 
export g='\033[32m' 
export y='\033[33m'
export b='\033[34m'
export p='\033[35m'
export o='\033[0m' 
###############################################

## VARS YOU DON'T NEED TO TOUCH.
echo -e "${b}MAIN_DIR $g $MAIN_DIR$o"
if [ ! -d $MAIN_DIR ]; then
  echo -e "$y WARNING: Missing left4dead2 directory!$o"
fi

export STYX_DIR="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"
echo -e "${b}STYX_DIR: $g$STYX_DIR$o"

export L4D2CR="$STYX_DIR/l4d2-competitive-rework"
echo -e "${b}L4D2-Competitive-Rework: $g$L4D2CR$o"

if [ ! -d $L4D2CR ]; then
  echo -e "${y}WARNING: Mising L4D2-Competitive-Rework directory!$o"
fi

export PLG_DIR="$MAIN_DIR/addons/sourcemod/plugins"

export SM_DIR="$L4D2CR/addons/sourcemod/scripting"

if [ ! -x $SM_DIR/spcomp ]; then
  echo -e "$y WARNING: Missing sourcemod compiler.$o"
else
  if [ "$temp_smdir" != "$SM_DIR" ]; then
    echo -e "Add $b$SM_DIR$o to PATH"
    export PATH=$SM_DIR:$PATH
    export temp_smdir=$SM_DIR
  fi
fi