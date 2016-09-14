#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="kafkamanager"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"

APP_PKG_DIR="${APP_ROOT}/packages"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}"
TMP_IMG="${ZETA_DOCKER_REG_URL}/kmgrbuilder"


mkdir -p $APP_PKG_DIR


APP_GIT_ROOT="https://github.com"
APP_GIT_USER="yahoo"
APP_GIT_REPO="kafka-manager"
APP_GIT="$APP_GIT_ROOT/$APP_GIT_USER/$APP_GIT_REPO"


REQ_APP_IMG_NAME="buildbase"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

for IMG in $REQ_APP_IMG_NAME; do
    RQ_IMG_CHK=$(sudo docker images|grep "\/${IMG}")
    if [ "$RQ_IMG_CHK" == "" ]; then
        echo "This install requires the the image $IMG"
        echo "Please install this package before proceeding"
        exit 1
    fi
done

BUILD_TMP="./tmpbuilder"
BUILD="Y"

DCK_CHK=$(sudo docker images|grep $TMP_IMG)
if [ "$DCK_CHK" != "" ]; then
    echo "$TMP_IMG Already Exits, rebuild?"
    read -e -p "Rebuild $APP_IMG? " -i "N" REBUILD
    if [ "$REBUILD" == "Y" ]; then
        sudo docker rmi -f $APP_IMG
    else
        BUILD="N"
    fi
fi


if [ "$BUILD" == "Y" ]; then
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > ./Dockerfile << EOF
FROM ${ZETA_DOCKER_REG_URL}/buildbase
RUN apt-get install -y openjdk-8-jdk && apt-get clean && apt-get autoremove -y

RUN git clone $APP_GIT && pwd

WORKDIR /app/kafka-manager

RUN git fetch origin pull/282/head:local282

RUN git checkout local282

RUN ./sbt clean dist

RUN apt-get install -y unzip

RUN mkdir -p /app/tmp && cp /app/kafka-manager/target/universal/*.zip /app/tmp/ && cd /app/tmp && export APP_ZIP=\$(ls /app/tmp/) && unzip \$APP_ZIP && export APP_VER=\$(echo \$APP_ZIP|sed "s/\.zip//") && tar zcf \$APP_VER.tgz \$APP_VER && rm /app/tmp/\$APP_ZIP && rm -rf /app/tmp/\$APP_VER


CMD ["/bin/bash"]
EOF


    sudo docker build -t $TMP_IMG .
    #rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi


mkdir -p $BUILD_TMP
cd $BUILD_TMP

CID=$(sudo docker run -d $TMP_IMG sleep 30)
APP_TGZ=$(sudo docker exec $CID ls /app/tmp)
sudo docker kill $CID
sudo docker rm $CID

APP_VER=$(echo $APP_TGZ|sed "s/\.tgz//")

if [ -f "$APP_PKG_DIR/$APP_TGZ" ]; then
    echo "This package already exists, do you wish to replace?"
    read -e -p "Replace $APP_PKG_DIR/$APP_TGZ? " -i "N" REPLACE
else
    REPLACE="Y"
fi
if [ "$REPLACE" == "Y" ]; then
    echo "Replacing"
    CURDIR=$(pwd)
    echo $CURDIR
    sudo docker run -t --rm -v=$CURDIR/:/app/out $TMP_IMG cp /app/tmp/$APP_TGZ /app/out/
    cp $APP_TGZ $APP_PKG_DIR/


else
    echo "Not Replacing"
fi
cd ..
rm -rf $BUILD_TMP


echo $APP_VER
echo $APP_TGZ
echo ""
echo "$APP_NAME built"
echo "You can install instances with $APP_ROOT/install_instance.sh"
echo ""
