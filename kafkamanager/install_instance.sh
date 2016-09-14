#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}"

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


echo "Application root is: $APP_ROOT"
echo "Application home is: $APP_HOME"

mkdir -p $APP_HOME
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
read -e -p "Please enter a http port to use with $APP_NAME: " -i "26666" APP_PORT
echo ""

DCK_CHK=$(sudo docker images|grep $APP_IMG)
if [ "$DCK_CHK" == "" ]; then
    echo "Image not built, we will build one using one of the current packages"
    echo ""
    ls -ls $APP_PKG_DIR
    echo ""
    echo ""
    read -e -p "Please choose a TGZ to package with your image, if it doesn't exist, this will end: " -i "kafka-manager-1.3.1.6.tgz" APP_TGZ
    APP_VER=$(echo $APP_TGZ|sed "s/\.tgz//")
    if [ ! -f "$APP_PKG_DIR/$APP_TGZ" ]; then
        echo "It's not there!!"
        exit 1
    fi
    BUILD_TMP="./tmpbuild"
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    cp $APP_PKG_DIR/$APP_TGZ ./
cat > ./Dockerfile << EOU
FROM ${ZETA_DOCKER_REG_URL}/maprbase

ADD $APP_TGZ /app/
WORKDIR /app/$APP_VER
EOU
    sudo docker build -t $APP_IMG .
    sudo docker push $APP_IMG
    cd ..
    rm -rf $BUILD_TMP
fi

cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": 1,
  "mem": 512,
  "cmd": "bin/kafka-manager",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "ZK_HOSTS": "$ZETA_ZKS"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 9000, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    }
  }
}
EOL

echo ""
echo ""
echo "Instance created at ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/start_instance.sh"
echo ""
echo ""




