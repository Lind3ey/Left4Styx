#!/bin/bash
source setup_env.sh

if [ -d $MAIN_DIR ] && [ -d $MAIN_DIR ]; then 
    echo LCR:$LCR
    echo MAIN_DIR:$MAIN_DIR
else
    echo missing env setup.
    exit 0
fi
echo "Copying L4d2-competitive-rework files."
cp $LCR/addons  $MAIN_DIR/ -r
cp $LCR/cfg     $MAIN_DIR/ -r
cp $LCR/scripts $MAIN_DIR/ -r
echo "Final files shall be deleted."
ls $PLG_DIR/*fun*
rm $PLG_DIR/*fun*

source ./install_styx.sh

if [ -d ./personal ]; then
  cp ./personal/* -r $MAIN_DIR/
fi 