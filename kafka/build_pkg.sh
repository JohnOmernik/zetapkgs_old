#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="kafka"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"


mkdir -p $APP_ROOT
mkdir -p $APP_PKG_DIR

BUILD_TMP="./tmpbuilder"

#APP_URL_ROOT="https://archive.apache.org/dist/kafka/0.9.0.1/"
#APP_URL_FILE="kafka_2.10-0.9.0.1.tgz"

APP_URL_ROOT="https://archive.apache.org/dist/kafka/0.10.0.1/"
APP_URL_FILE="kafka_2.10-0.10.0.1.tgz"
APP_URL="${APP_URL_ROOT}${APP_URL_FILE}"


REQ_APP_IMG_NAME="maprbase buildbase"

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


APP_GIT_URL="https://github.com"
APP_GIT_USER="mesos"
APP_GIT_REPO="kafka"

BUILD="Y"
TMP_IMG="zeta/kafkabuild"
if [ "$BUILD" == "Y" ]; then
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP



    if [ "$ZETA_DOCKER_PROXY" != "" ]; then
        P_HOST=$(echo $ZETA_DOCKER_PROXY|cut -f2 -d":"|sed "s@//@@")
	P_PORT=$(echo $ZETA_DOCKER_PROXY|cut -f3 -d":")
        echo "Proxy Host: $P_HOST"
	echo "Proxy Port: $P_PORT"
	DOCKERLINE="ENV JAVA_OPTS -Dhttp.proxyHost=$P_HOST -Dhttp.proxyPort=$P_PORT -Dhttps.proxyHost=$P_HOST -Dhttps.proxyPort=$P_PORT"
    else
        DOCKERLINE=""
    fi


cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/buildbase
$DOCKERLINE
RUN git clone ${APP_GIT_URL}/${APP_GIT_USER}/$APP_GIT_REPO
RUN cd ${APP_GIT_REPO} && echo "\$JAVA_OPTS" && ./gradlew jar -x test && cd ..
RUN mkdir -p kafka-mesos && cp ./$APP_GIT_REPO/kafka-mesos-*.jar ./kafka-mesos/ && cp ./$APP_GIT_REPO/kafka-mesos.sh ./kafka-mesos/
RUN wget $APP_URL && mv $APP_URL_FILE ./kafka-mesos/
CMD ["/bin/sleep 10"]
EOL

    sudo docker build -t $TMP_IMG .
    CID=$(sudo docker run -d zeta/kafkabuild sleep 10)
    sudo docker cp $CID:/app/kafka-mesos ./
    sudo docker kill $CID
    sudo docker rm $CID
    sudo docker rmi -f zeta/kafkabuild
    cd ..
    JAR=$(ls $BUILD_TMP/kafka-mesos/*.jar|sed "s/\.jar//"|sed "s@$BUILD_TMP\/kafka-mesos\/@@")
    TGZ=$(ls $BUILD_TMP/kafka-mesos/*.tgz|sed "s/\.tgz//"|sed "s@$BUILD_TMP\/kafka-mesos\/@@")
    cd $BUILD_TMP
    PKG_TGZ="${JAR}-${TGZ}.tgz"
    tar zcf ${PKG_TGZ} ./kafka-mesos
    if [ -f "$APP_PKG_DIR/$PKG_TGZ" ]; then
        echo "The currently built TGZ ${PKG_TGZ} already exists in $APP_PKG_DIR"
        echo "Do you wish to replace the existing one in the package directory with the recently built version?"
        read -e -p "Replace package? " -i "N" REPLACE_TGZ
    else
        REPLACE_TGZ="Y"
    fi
    if [ "$REPLACE_TGZ" == "Y" ]; then
        mv ${PKG_TGZ} ${APP_PKG_DIR}/
    fi
    cd ..
else
    echo "Will not rebuild"
fi



sudo rm -rf $BUILD_TMP
echo ""
echo "kafka built"
echo "You can install instances with $APP_ROOT/install_instance.sh"
echo ""
