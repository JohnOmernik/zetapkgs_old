#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="spark"


APP_VER_FILE=$1
if [ "$APP_VER_FILE" == "" ]; then
    echo "You must specify which version of drill you wish to build by passing the appropriate .vers file to this script"
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


APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"

mkdir -p $APP_PKG_DIR

BUILD_TMP="./tmpbuilder"

REQ_APP_IMG_NAME="maprbase"

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


IMG_CHK=$(sudo docker images|grep "\/${APP_IMG}")
if [ "$IMG_CHK" != "" ]; then
    echo "A ${APP_IMG} image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi

if [ ! -f "${APP_PKG_DIR}/${APP_URL_FILE}" ]; then
    wget ${APP_URL}
    mv ${APP_URL_FILE} ${APP_PKG_DIR}/
fi


if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/${REQ_APP_IMG_NAME}

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python libnss3 python-numpy python-dev python-pip git curl && apt-get clean && apt-get autoremove -y

RUN pip install xxhash && pip install lz4tools && pip install kafka-python && pip install requests

EOL

    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG

    cd ..
else
    echo "Will not rebuild"
fi

rm -rf $BUILD_TMP

echo ""
echo "${APP_NAME} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo ""
