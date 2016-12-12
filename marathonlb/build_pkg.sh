#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="marathonlb"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/$APP_NAME"
APP_PKG_DIR="${APP_ROOT}/packages"

mkdir -p $APP_ROOT
mkdir -p $APP_PKG_DIR

BUILD_TMP="./tmpbuilder"

APP_VER_FILE=$1
if [ "$APP_VER_FILE" == "" ]; then
    echo "You must specify which version of $APP_NAME you wish to build by passing the appropriate .vers file to this script"
    echo "Current options are:"
    echo ""
    ls *.vers
    exit 1
fi

if [ ! -f "$APP_VER_FILE" ]; then
    echo "The provided vers file $APP_VER_FILE does not appear to exist.  Please choose from these options:"
    echo ""
    ls *.vers
    exit 1
fi
. $APP_VER_FILE

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

IMG_CHK=$(sudo docker images|grep "$APP_NAME"|grep "$APP_VER")
if [ "$IMG_CHK" != "" ]; then
    # First Check for Image, if it doesn't exist, try pulling it
    sudo docker pull ${APP_IMG}
    IMG_CHK=$(sudo docker images|grep "$APP_NAME"|grep "$APP_VER")
    # Then check again
    if [ "$IMG_CHK" != "" ]; then
        # If it does exist, ask about rebuilding
        echo "A ${APP_IMG} image was already identified. Do you wish to rebuild?"
        read -e -p "Rebuild? " -i "N" BUILD
    fi
else
    BUILD="Y"
fi
. $APP_VER_FILE

cp $APP_VER_FILE $APP_PKG_DIR/
echo ""
echo "${APP_IMG} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo ""
