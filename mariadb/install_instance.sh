#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
APP_LIST_ALL="1"
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
APP_LOCK_DIR="$APP_HOME/lock"
APP_CRED_DIR="$APP_HOME/creds"

mkdir -p $APP_DATA_DIR
mkdir -p $APP_LOCK_DIR
mkdir -p $APP_CRED_DIR
sudo chown -R zetaadm:zeta${APP_ROLE}apps $APP_CRED_DIR
sudo chmod 770 $APP_CRED_DIR


APP_MARATHON_FILE="$APP_HOME/${APP_ID}.marathon"

echo "You need a port to run MariaDB on"
echo ""
read -e -p "Please enter a port to use with mariadb: " -i "30306" APP_PORT
echo ""

cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": 1,
  "mem": 2048,
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${ZETA_DOCKER_REG_URL}/${APP_NAME}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 3306, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
  "volumes": [
      {
        "containerPath": "/var/lib/mysql",
        "hostPath": "${APP_DATA_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/lock",
        "hostPath": "${APP_LOCK_DIR}",
        "mode": "RW"
      },
      {
        "containerPath": "/creds",
        "hostPath": "${APP_CRED_DIR}",
        "mode": "RW"
      }
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




