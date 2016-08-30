#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_URL_FILE="spark-2.0.0-bin-without-hadoop.tgz"
APP_URL_BASE="http://mirror.cc.columbia.edu/pub/software/apache/spark/spark-2.0.0/"

APP_URL="${APP_URL_BASE}${APP_URL_FILE}"

APP_IMG_NAME="sparkbase"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_IMG_NAME}"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/spark"
APP_PKG_DIR="${APP_ROOT}/packages"

mkdir -p $APP_ROOT
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


IMG_CHK=$(sudo docker images|grep "\/${APP_IMG_NAME}")
if [ "$IMG_CHK" != "" ]; then
    echo "A ${APP_IMG_NAME} image was already identified. Do you wish to rebuild?"
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

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python libnss3 python-numpy curl && apt-get clean && apt-get autoremove -y

EOL

    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG

    cd ..
else
    echo "Will not rebuild"
fi

rm -rf $BUILD_TMP

echo ""
echo "${APP_IMG_NAME} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo ""
