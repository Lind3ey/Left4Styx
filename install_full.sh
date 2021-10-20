#!/bin/bash
source ./setup_env.sh || return 1

if [ $L4D2CR ] && [ $MAIN_DIR ] && [ -d $L4D2CR ] && [ -d $MAIN_DIR ]; then 
    echo -e "$b L4D2 Competitive Rework: $o$L4D2CR"
    echo -e "$b Left 4 Dead 2 : $o$MAIN_DIR"
else
    echo -e "$r ERROR : missing env setup.$o"
    return 1 || exit 1
fi
echo -e "$b Copying L4d2-competitive-rework files.$o"
cp $L4D2CR/addons  $MAIN_DIR/ -r
cp $L4D2CR/cfg     $MAIN_DIR/ -r
cp $L4D2CR/scripts $MAIN_DIR/ -r
echo -e "$r Following files will be deleted.$o"
echo $PLG_DIR/../scripting
ls $PLG_DIR/*fun*
rm $PLG_DIR/*fun*
rm $PLG_DIR/../scripting -r

source ./install_styx.sh || return 1
return 0