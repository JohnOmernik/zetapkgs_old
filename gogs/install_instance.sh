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

APP_DATA_DIR="$APP_HOME/data"
APP_CERT_LOC="${APP_HOME}/certs"

mkdir -p $APP_DATA_DIR
mkdir -p ${APP_CERT_LOC}
sudo chmod -R 770 ${APP_CERT_LOC}


CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"

echo "The Gogs git server needs two ports, a SSH port and a HTTP port"
echo ""
read -e -p "Please enter a ssh port to use with gogs: " -i "30022" APP_SSH_PORT
echo ""
read -e -p "Please enter a http port to use with gogs: " -i "30443" APP_HTTP_PORT
echo ""

cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": 2,
  "mem": 2048,
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 22, "hostPort": ${APP_SSH_PORT}, "servicePort": 0, "protocol": "tcp"},
        { "containerPort": 3000, "hostPort": ${APP_HTTP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/data", "hostPath": "${APP_DATA_DIR}", "mode": "RW" }
    ]

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




