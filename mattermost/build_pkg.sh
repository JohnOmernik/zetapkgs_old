#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="mattermost"

APP_IMG_DB="${ZETA_DOCKER_REG_URL}/${APP_NAME}_db"
APP_IMG_APP="${ZETA_DOCKER_REG_URL}/${APP_NAME}_app"
APP_IMG_WEB="${ZETA_DOCKER_REG_URL}/${APP_NAME}_web"

GIT_REPO="https://github.com/mattermost/mattermost-docker.git"

BUILD_TMP="./tmpbuilder"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

MM_CHK=$(sudo docker images|grep "\/${APP_NAME}")
if [ "$MM_CHK" != "" ]; then
    echo "A mattermost image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi



if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    git clone $GIT_REPO
    cd mattermost-docker

    echo "Building DB"
    cd db

    if [ "$ZETA_DOCKER_PROXY" != "" ]; then
        DOCKER_LINE1="ENV http_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE2="ENV HTTP_PROXY=$ZETA_DOCKER_PROXY"
        DOCKER_LINE3="ENV https_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE4="ENV HTTPS_PROXY=$ZETA_DOCKER_PROXY"
	sed -i "/MAINTAINER /a $DOCKER_LINE4" Dockerfile
	sed -i "/MAINTAINER /a $DOCKER_LINE3" Dockerfile
	sed -i "/MAINTAINER /a $DOCKER_LINE2" Dockerfile
	sed -i "/MAINTAINER /a $DOCKER_LINE1" Dockerfile
    fi

    sudo docker build -t $APP_IMG_DB . 
    sudo docker push $APP_IMG_DB
    cd ..

    echo "Building App"
    cd app

    if [ "$ZETA_DOCKER_PROXY" != "" ]; then
        DOCKER_LINE1="ENV http_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE2="ENV HTTP_PROXY=$ZETA_DOCKER_PROXY"
        DOCKER_LINE3="ENV https_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE4="ENV HTTPS_PROXY=$ZETA_DOCKER_PROXY"
    sed -i "/MAINTAINER /a $DOCKER_LINE4" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE3" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE2" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE1" Dockerfile
    fi

    sudo docker build -t $APP_IMG_APP . 
    sudo docker push $APP_IMG_APP
    cd ..

    echo "Building Web"
    cd web

    if [ "$ZETA_DOCKER_PROXY" != "" ]; then
        DOCKER_LINE1="ENV http_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE2="ENV HTTP_PROXY=$ZETA_DOCKER_PROXY"
        DOCKER_LINE3="ENV https_proxy=$ZETA_DOCKER_PROXY"
        DOCKER_LINE4="ENV HTTPS_PROXY=$ZETA_DOCKER_PROXY"
    sed -i "/MAINTAINER /a $DOCKER_LINE4" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE3" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE2" Dockerfile
    sed -i "/MAINTAINER /a $DOCKER_LINE1" Dockerfile
    fi

    sudo docker build -t $APP_IMG_WEB .
    sudo docker push $APP_IMG_WEB
    cd ..



    cd ..
    cd ..
    rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi


echo ""
echo "$APP_NAME Images pushed to cluster shared docker and ready to role at:"
echo "$APP_IMG_DB"
echo "$APP_IMG_APP"
echo "$APP_IMG_WEB"
echo ""
