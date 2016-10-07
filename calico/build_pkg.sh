#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="calico"
APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
mkdir -p $APP_ROOT
APP_PKGS=${APP_ROOT}/packages
mkdir -p $APP_PKGS

BUILD_TMP="./tmpbuilder"

APP_IMG_NODE="caliconode"
APP_IMG_LIB="calicolibnet"

APP_NODE="${ZETA_DOCKER_REG_URL}/${APP_IMG_NODE}"
APP_LIB="${ZETA_DOCKER_REG_URL}/${APP_IMG_LIB}"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

APP_VER="v0.22.0"
APP_URL_BASE="https://github.com/projectcalico/calico-containers/releases/download/"
APP_URL_FILE="calicoctl"

APP_URL="${APP_URL_BASE}${APP_VER}/${APP_URL_FILE}"




IMG_CHK=$(sudo docker images|grep "\/${APP_IMG_NODE}")
if [ "$IMG_CHK" != "" ]; then
    echo "A ${APP_IMG_NODE} image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    IMG_CHK2=$(sudo docker images|grep "\/${APP_IMG_LIB}")
    if [ "$IMG_CHK2" != "" ]; then
       echo "A ${APP_IMG_LIB} image was already identified. Do you wish to rebuild?"
        read -e -p "Rebuild? " -i "N" BUILD
    else
        BUILD="Y"
    fi
fi

APP_SRC_NODE="calico/node"
APP_SRC_LIB="calico/node-libnetwork"


if [ ! -f "${APP_PKGS}/${APP_URL_FILE}.${APP_VER}" ]; then
    echo "Requested version of calicoctl doesn't exist... Downloading"
    wget $APP_URL
    mv $APP_URL_FILE ${APP_PKGS}/${APP_URL_FILE}.${APP_VER}
fi


if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP



    sudo docker pull $APP_SRC_NODE
    sudo docker pull $APP_SRC_LIB

    sudo docker tag $APP_SRC_NODE $APP_NODE
    sudo docker tag $APP_SRC_LIB $APP_LIB

    sudo docker push $APP_NODE
    sudo docker push $APP_LIB

    cd ..
else
    echo "Will not rebuild"
fi

rm -rf $BUILD_TMP

echo ""
echo "${APP_IMG_NODE} and ${APP_IMG_LIB} images pushed to cluster shared docker and ready to use"
echo "Now install calico at $APP_ROOT/install_instance.sh"
echo ""
