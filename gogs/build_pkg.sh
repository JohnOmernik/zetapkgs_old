#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_IMG="${ZETA_DOCKER_REG_URL}/gogs"

GIT_REPO="https://github.com/gogits/gogs.git"

BUILD_TMP="./tmpbuilder"


DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi


GOGS_CHK=$(sudo docker images|grep "\/gogs")
if [ "$GOGS_CHK" != "" ]; then
    echo "A gogs image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi

if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    git clone $GIT_REPO
    cd gogs
    sed -i "s/adduser /adduser -u 2500 /" ./docker/build.sh
    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG
    cd ..
    cd ..
    rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi


echo ""
echo "Gogs Image pushed to cluster shared docker and ready to role at $APP_IMG"
echo ""
