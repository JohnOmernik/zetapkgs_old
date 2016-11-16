#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="mongo"


GIT_REPO="https://github.com/docker-library/mongo.git"
APP_VER="3.3"
BUILD_TMP="./tmpbuilder"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}:${APP_VER}"




DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi


MONGO_CHK=$(sudo docker images|grep "\/${APP_NAME}")
if [ "$MONGO_CHK" != "" ]; then
    echo "A mongo image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi



if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    git clone $GIT_REPO
    cd mongo
    cd $APP_VER
    sed -i "s/groupadd /groupadd -g 2500 /g" Dockerfile
    sed -i "s/useradd /useradd -u 2500 /g" Dockerfile


    if [ "$ZETA_DOCKER_PROXY" != "" ]; then
        DOCKER_LINE1="ENV http_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE2="ENV HTTP_PROXY=$ZETA_DOCKER_PROXY"
        DOCKER_LINE3="ENV https_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE4="ENV HTTPS_PROXY=$ZETA_DOCKER_PROXY"
        DOCKER_LINE5="ENV NO_PROXY=$DOCKER_NOPROXY"
        DOCKER_LINE6="ENV no_proxy=$DOCKER_NOPROXY"
        sed -i "/FROM /a $DOCKER_LINE1" Dockerfile
        sed -i "/FROM /a $DOCKER_LINE2" Dockerfile
        sed -i "/FROM /a $DOCKER_LINE3" Dockerfile
        sed -i "/FROM /a $DOCKER_LINE4" Dockerfile
        sed -i "/FROM /a $DOCKER_LINE5" Dockerfile
        sed -i "/FROM /a $DOCKER_LINE6" Dockerfile
    fi


    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG
    cd ..
    cd ..
    cd ..
    rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi


echo ""
echo "$APP_NAME Image pushed to cluster shared docker and ready to role at $APP_IMG"
echo ""
