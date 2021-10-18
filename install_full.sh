#!/bin/bash
source setup_env.sh

if [ -d $L4D2CR ] && [ -d $MAIN_DIR ]; then 
    echo -e "\033[32m L4D2 Competitive Rework: \033[0m$L4D2CR"
    echo -e "\033[32m Left 4 Dead 2 : \033[0m$MAIN_DIR"
else
    echo -e "\033[31m Error:missing env setup.\033[0m"
    exit 0
fi
echo -e "\033[32mCopying L4d2-competitive-rework files.\033[0m"
cp $L4D2CR/addons  $MAIN_DIR/ -r
cp $L4D2CR/cfg     $MAIN_DIR/ -r
cp $L4D2CR/scripts $MAIN_DIR/ -r
echo -e "\033[31mFollowing files will be deleted.\033[0m"
echo $PLG_DIR/../scripting
ls $PLG_DIR/*fun*
rm $PLG_DIR/*fun*
rm $PLG_DIR/../scripting -r

source ./install_styx.sh

if [ -d ./custom ]; then
  cp ./custom/* -r $MAIN_DIR/
fi 