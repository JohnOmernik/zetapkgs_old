#!/bin/bash


APP_ROLE_GUESS=$(echo "$(realpath "$0")"|cut -d"/" -f2-)

SCRIPT_NAME=$(basename $0)
APP_ROLE_GUESS1=$(echo "$(realpath "$0")"|cut -d"/" -f2-|sed "s@/$SCRIPT_NAME@@")

basename $0


echo $APP_ROLE_GUESS
echo $APP_ROLE_GUESS1
