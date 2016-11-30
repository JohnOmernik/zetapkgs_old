#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="confluentbase"
APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"


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

mkdir -p $APP_ROOT

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

rm -rf $BUILD_TMP

echo ""
echo "${APP_IMG} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo "No instance installs needed for this package"
echo ""
