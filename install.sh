#!/bin/bash


CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh


if [ ! -d "/mapr/$CLUSTERNAME/zeta/shared/preinst" ]; then
    echo "preinst directory not installed to cluster, do you wish you copy preinst includes?"
    echo "Saying no now, will make installs on the cluster fail"
    read -e -p "Install preinst includes? " -i "Y" PREINST
    if [ "$PREINST" == "Y" ]; then
        mkdir -p /mapr/$CLUSTERNAME/zeta/shared/preinst
        cp ./preinst/* /mapr/$CLUSTERNAME/zeta/shared/preinst/
    fi
fi


APP_IN=$1
APP_NAME=$(echo $APP_IN|sed "s@/@@")

FORCE=$2

CHK=$(ls -ls|grep " drw"|grep "$APP_NAME")

if [ "$APP_NAME" == "archive" ]; then
    echo "The archive directory is not an installable package"
    echo "Exiting"
    exit 1
fi



if [ "$APP_NAME" == "" ]; then
    echo ""
    echo "You must specify a package listed here:"
    echo ""
    ls -ls|grep " drw"
    exit 1
fi

if [ "$CHK" == "" ]; then
    echo ""
    echo "The package you specified $APP_NAME does not exist"
    echo ""
    ls -ls|grep " drw"
    exit 1
fi

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/$APP_NAME"

if [ -d "$APP_ROOT" ]; then
    if [ "$FORCE" != "1" ]; then 
        echo "There is already a shared preinst package for $APP_NAME at $APP_ROOT"
        echo "Exiting Now"
        exit 1
    fi
fi

echo ""
echo "*********************************************"
echo "Requested preinst for package $APP_NAME"
echo "To be installed $APP_ROOT"
echo ""
read -e -p "Is this correct? " -i N INST

if [ "$INST" != "Y" ]; then
    echo "Aborted by user"
    exit 1
fi

mkdir -p $APP_ROOT
cp ./$APP_NAME/* $APP_ROOT/

echo ""
echo "Initial scripts moved to preinst location $APP_ROOT"
echo "Now you should run $APP_ROOT/build_pkg.sh to get a local copy installed for use on your cluster"
echo ""

