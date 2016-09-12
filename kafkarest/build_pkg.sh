#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh


APP_NAME="kafkarest"
APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"

mkdir -p $APP_ROOT
mkdir -p $APP_PKG_DIR

BUILD_TMP="./tmpbuilder"
APP_IMG_NAME="confluentbase"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_IMG_NAME}"

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


APP_URL_BASE="http://packages.confluent.io/archive/3.0/"
APP_URL_FILE="confluent-3.0.1-2.11.tar.gz"
APP_VER="confluent-3.0.1"



APP_URL="${APP_URL_BASE}${APP_URL_FILE}"

if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/${REQ_APP_IMG_NAME}

RUN mkdir -p /app 
WORKDIR /app

RUN wget $APP_URL && tar zxf $APP_URL_FILE

CMD ["/bin/bash"]

EOL

    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG

    cd ..
else
    echo "Will not rebuild"
fi

REPLACE_TGZ="Y"
if [ -f "${APP_PKG_DIR}/${APP_VER}_conf_default.tgz" ]; then
    echo "There already appears to be a ${APP_VER}_conf_default.tgz tarball, do you wish to replace a fresh copy from the confluent base image?"
    read -e -p "Replace default conf Tarball? " -i "N" REPLACE_TGZ
fi

if [ "$REPLACE_TGZ" == "Y" ]; then

    CID=$(sudo docker run -d ${APP_IMG} sleep 15)

    sudo docker cp ${CID}:/app/${APP_VER}/etc/kafka-rest ./
    sudo chown zetaadm:zetaadm ./kafka-rest
    mv ./kafka-rest ./kafka-rest-conf
    tar zcf ./${APP_VER}_conf_defaults.tgz ./kafka-rest-conf
    mv ${APP_VER}_conf_defaults.tgz $APP_PKG_DIR/
    sudo docker kill $CID
    sudo docker rm $CID
    rm -rf ./kafka-rest-conf
fi

rm -rf $BUILD_TMP

echo ""
echo "${APP_IMG_NAME} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo "No instance installs needed for this package"
echo ""
