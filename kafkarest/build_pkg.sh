#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh


APP_NAME="kafkarest"
APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"

mkdir -p $APP_ROOT
mkdir -p $APP_PKG_DIR

BUILD_TMP="./tmpbuilder"

REQ_APP_IMG_NAME="confluent"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

RQ_IMG_CHK=$(sudo docker images|grep "\/${REQ_APP_IMAGE_NAME}")
if [ "$RQ_IMG_CHK" == "" ]; then
    echo "This install requires the the image $REQ_APP_IMG_NAME"
    echo "Please install this package before proceeding"
    exit 1
fi

echo "Which version of Kafka rest would you like to use?"
echo ""
sudo docker images --format "table {{.Repository}} -->   {{.Tag}}"|grep confluent
echo ""
read -e -p "Tag: " -i "3.0.1-2.11" APP_VER

APP_IMG="${ZETA_DOCKER_REG_URL}/confluent:${APP_VER}"
APP_TGZ="confluent-kafkarest-${APP_VER}.tgz"



if [ -f "$APP_PKG_DIR/$APP_TGZ" ]; then
    echo "The App package tgz already exists at ${APP_PKG_DIR}/$APP_TGZ do you wish to pull a fresh one from $APP_IMG?"
    read -e -p "Pull fresh conf from $APP_IMG? " -i "N" BUILD
else
    BUILD="Y"
fi

APP_MAJ_VER=$(echo $APP_VER|cut -d"-" -f 1)
APP_FULL_MAJ_VER="confluent-${APP_MAJ_VER}"

if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    CID=$(sudo docker run -d ${APP_IMG} sleep 15)
    sudo docker cp ${CID}:/app/${APP_FULL_MAJ_VER}/etc/kafka-rest ./
    sudo chown zetaadm:zetaadm ./kafka-rest
    mv ./kafka-rest ./kafka-rest-conf
    tar zcf ./${APP_TGZ} ./kafka-rest-conf
    mv ${APP_TGZ} $APP_PKG_DIR/
    sudo docker kill $CID
    sudo docker rm $CID
    rm -rf ./kafka-rest-conf
    cd ..
fi

rm -rf $BUILD_TMP

echo ""
echo "${APP_TGZ} defaults saved to $APP_PKG_DIR"
echo "Now use install instance at $APP_ROOT/install_instance.sh to select an instance to install"
echo ""
