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


. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_${APP_ROLE}.sh




#read -e -p "Please enter the service port for ${APP_ID} instance of ${APP_NAME}: " -i "28101" APP_PORT

read -e -p "Please enter the memory limit for for ${APP_ID} instance of ${APP_NAME}: " -i "384" APP_MEM

read -e -p "Please enter the cpu limit for for ${APP_ID} instance of ${APP_NAME}: " -i "0.2" APP_CPU

echo "A numbers of defaults are set in the scheduler, pleaes review the marathon.json before starting"





##########
# Do instance specific things: Create Dirs, copy start files, make executable etc

# Placing def confs
mkdir -p $APP_HOME
cd $APP_HOME
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
chmod +x ${APP_HOME}/start_instance.sh

APP_MARATAHON_FILE="${APP_HOME}/marathon.json"
cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "instances": 1,
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "container": {
    "docker": {
      "forcePullImage": true,
      "image": "${APP_IMG}"
    },
    "type": "DOCKER"
  },
  "env": {
    "FRAMEWORK_NAME": "${APP_ID}",
    "WEBURI": "http://${APP_ID}.${APP_ROLE}.marathon.mesos:$PORT0/stats",
    "MESOS_MASTER": "zk://master.mesos:2181/mesos",
    "ZK_PERSIST": "zk://master.mesos:2181/etcd",
    "AUTO_RESEED": "true",
    "RESEED_TIMEOUT": "240",
    "CLUSTER_SIZE": "3",
    "CPU_LIMIT": "1",
    "DISK_LIMIT": "4096",
    "MEM_LIMIT": "2048",
    "VERBOSITY": "1"
  },
  "healthChecks": [
    {
      "gracePeriodSeconds": 60,
      "intervalSeconds": 30,
      "maxConsecutiveFailures": 0,
      "path": "/healthz",
      "portIndex": 0,
      "protocol": "HTTP"
    }
  ],
  "ports": [
    0,
    1,
    2
  ]
}
EOL


echo ""
echo ""
echo "Instance created at ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/start_instance.sh"
echo ""
echo ""




