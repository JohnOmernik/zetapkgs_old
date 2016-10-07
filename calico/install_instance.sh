#!/bin/bash

CLUSTERNAME=$(ls /mapr)

echo ""
echo ""
echo "Since this is a one per cluster install, this must be installed in the shared role, in the directory zeta, with the ID of zetacalico"
echo ""
echo "Any other options given will cause the script to exit out and fail"
echo ""
echo ""

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
APP_LIST_ALL="1"

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_NODE="${ZETA_DOCKER_REG_URL}/caliconode"
APP_LIB="${ZETA_DOCKER_REG_URL}/calicolibnet"

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


echo "Application root is: $APP_ROOT"
echo "Application home is: $APP_HOME"

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_${APP_ROLE}.sh

if [ "$APP_ID" != "zetacalico" ]; then
    echo "APP_ID must be zetacalico"
    exit 1
fi
if [ "$APP_ROLE" != "shared" ]; then
    echo "APP_ROLE must be shared"
    exit 1
fi
if [ "$APP_DIR" != "zeta" ]; then
    echo "APP_DIR must be zeta"
    exit 1
fi

APP_PKGS="${APP_ROOT}/packages"

echo "*******************************"
echo ""
ls -1 ${APP_PKGS}
echo ""
echo ""
echo "Please enter the version of calicoctl to copy to this instance"
read -e -p "calicoctl version: " -i "calicoctl.v0.22.0" APP_VER




read -e -p "Please enter the memory limit for for ${APP_ID} instance of ${APP_ID}: " -i "196" APP_MEM
read -e -p "Please enter the cpu limit for for ${APP_ID} instance of ${APP_ID}: " -i "0.2" APP_CPU
read -e -p "Please enter the framework name for the etcd mesos instance to use for ${APP_ID}: " -i "etcdcalico" APP_CALICO

APP_ETCD_IMG="${ZETA_DOCKER_REG_URL}/etcd"

##########
# Do instance specific things: Create Dirs, copy start files, make executable etc

# Placing def confs
mkdir -p $APP_HOME
cd $APP_HOME
cp ${APP_PKGS}/$APP_VER ${APP_HOME}/calicoctl
chmod +x ${APP_HOME}/calicoctl


cp ${APP_ROOT}/check_and_install.sh ${APP_HOME}/
chmod +x ${APP_HOME}/check_and_install.sh
mkdir -p ${APP_HOME}/marathon_templates
APP_PROX_MAR="${APP_HOME}/marathon_templates/etcd_proxy.template"
APP_NODE_MAR="${APP_HOME}/marathon_templates/node.template"
APP_NETLIB_MAR="${APP_HOME}/marathon_templates/netlib.template"


cat > $APP_PROX_MAR << EOL
{
  "id": "${APP_ROLE}/${APP_ID}/etcdproxies/prox-%HOSTID%",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd":"/work/bin/etcd --proxy=on --discovery-srv=${APP_CALICO}.mesos",
  "instances": 1,
  "constraints": [["hostname", "LIKE", "%HOST%"],["hostname", "UNIQUE"]],
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_ETCD_IMG}",
      "network": "HOST"
    }
  }
}

EOL


cat > $APP_NODE_MAR << EOL1
{
  "id": "${APP_ROLE}/${APP_ID}/nodes/node-%HOSTID%",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "constraints": [["hostname", "LIKE", "%HOST%"],["hostname", "UNIQUE"]],
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "IP": "%HOST%",
    "FELIX_IGNORELOOSERPF": "true",
    "ETCD_ENDPOINTS": "http://localhost:2379",
    "ETCD_SCHEME": "http"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${ZETA_DOCKER_REG_URL}/caliconode",
    "privileged": true,
      "network": "HOST"
    },
    "volumes": [
      { "containerPath": "/lib/modules", "hostPath": "/lib/modules", "mode": "RW" },
      { "containerPath": "/var/run/calico", "hostPath": "/var/run/calico", "mode": "RW" }
    ]
  }
}
EOL1


cat > $APP_NETLIB_MAR << EOL2
{
  "id": "${APP_ROLE}/${APP_ID}/netlibs/netlib-%HOSTID%",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "constraints": [["hostname", "LIKE", "%HOST%"],["hostname", "UNIQUE"]],
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "ETCD_ENDPOINTS": "http://localhost:2379",
    "ETCD_SCHEME": "http"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${ZETA_DOCKER_REG_URL}/calicolibnet",
    "privileged": true,
      "network": "HOST"
    },
    "volumes": [
      { "containerPath": "/run/docker/plugins", "hostPath": "/run/docker/plugins", "mode": "RW" }
    ]
  }
}
EOL2


echo ""
echo ""
echo "Calico files created and copied to ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/create_and_install.sh"
echo ""
echo ""


