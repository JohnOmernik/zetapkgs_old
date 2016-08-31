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

APP_DATA_DIR="$APP_HOME/data"

mkdir -p $APP_DATA_DIR


APP_MARATHON_FILE="$APP_ROOT/${APP_ID}.marathon"

echo "The Gogs git server needs two ports, a SSH port and a HTTPS port"
echo ""
read -e -p "Please enter a ssh port to use with gogs: " -i "30022" APP_SSH_PORT
echo ""
read -e -p "Please enter a https port to use with gogs: " -i "30443" APP_HTTPS_PORT
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
        { "containerPort": 3000, "hostPort": ${APP_HTTPS_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/data", "hostPath": "${APP_DATA_DIR}", "mode": "RW" }
    ]

  }
}
EOL





