#!/bin/bash
CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh


APP_NAME="marathonlb"
APP_ROLE="shared"
APP_DIR="zeta"
APP_ID="sharedlb"
APP_ROOT="/mapr/${CLUSTERNAME}/${APP_DIR}/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"
APP_HOME="/mapr/${CLUSTERNAME}/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}"
APP_MARATHON_FILE="$APP_HOME/marathon.json"

APP_CERT_LOC="${APP_HOME}/certs"

if [ -d "$APP_HOME" ]; then
    echo "Install identified at $APP_HOME"
    echo "Will not reinstall"
    exit 1
fi

echo ""
echo "Marathon LB is a single instance install on Zeta at this time"
echo ""
echo "The following locations have been selected"
echo "APP_ROLE: $APP_ROLE"
echo "APP_ID: $APP_ID"
echo "APP_HOME: $APP_HOME"
echo ""



echo ""
echo "List of current packages of $APP_NAME:"
echo ""
ls -ls $APP_PKG_DIR
echo ""


read -e -p "Which version of $APP_NAME do you want to use? " -i "marathonlb-1.4.3.vers" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi
BUILD="N"
. $APP_BASE

mkdir -p $APP_HOME
mkdir -p $APP_CERT_LOC
mkdir -p ${APP_HOME}/templates
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
chmod +x ${APP_HOME}/start_instance.sh

sudo chmod -R 770 ${APP_CERT_LOC}

###############
# APP Specific

echo ""
echo "Marathon LB can only be installed once in the shared role."

echo ""
# Ports left in in case we go down the path of further configuration
#echo "Marathon-LB Ports: "
#read -e -p "Please enter the port for HAProxy Admin Access: " -i "9090" APP_HAPROXY_PORT
#read -e -p "Please enter the port for HAProxy Unified Access: " -i "9091" APP_HAPROXY_ALL_PORT
#read -e -p "Please enter the port for HAProxy HTTP Access: " -i "80" APP_HTTP_PORT
#read -e -p "Please enter the port for HAProxy HTTPS Access: " -i "443" APP_HTTPS_PORT
echo ""
echo "Resources for $APP_NAME"
read -e -p "Please enter the amount of Memory for $APP_NAME: " -i "1024" APP_MEM
read -e -p "Please enter the amount of CPU shares for $APP_NAME: " -i "1.0" APP_CPU
echo ""
read -e -p "How many edge nodes will you be running with $APP_NAME? " -i "2" APP_CNT
echo ""
echo "Please provide a Mesos contraint to pin $APP_NAME to a specific number of hosts (likely $APP_CNT)"
echo "For example, if you want to run it on two Mesos Agents with the host names 192.168.0.102 and 192.168.0.104 you could enter: 192.168.0.10[24]"
echo ""
read -e -p "Mesos Constraint: " APP_CONSTRAINT
echo ""
echo "Do you with to generate certificates with ZetaCA or use external enterprise trusted certs (recommended)?"
read -e -p "Generate certificates from Zeta CA? " -i "N" ZETA_CA_CERTS
echo ""
if [ "$ZETA_CA_CERTS" == "Y" ]; then
    CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"
    . /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_server_cert.sh
else
    echo "Please enter the certificate file name:"
    read -e -p "Certificate file: " -i "cert.pem" CERT_FILE_NAME
    echo ""
    echo "Please ensure there is a certificate there in ${APP_CERT_LOC} named $CERT_FILE_NAME"
    echo ""
fi

#  "constraints": [["hostname", "LIKE", "192.168.0.104"],["hostname", "UNIQUE"]],

##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cd ${APP_HOME}

##"--marathon-auth-credential-file", "/marathonlb/creds/marathon.txt",

cat > ${APP_MARATHON_FILE} << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": ${APP_CNT},
  "args":["sse", "--marathon", "http://${ZETA_MARATHON_URL}", "--group", "*"],
  "constraints": [["hostname", "LIKE", "$APP_CONSTRAINT"], ["hostname", "UNIQUE"]],
  "env": {
    "HAPROXY_SSL_CERT":"/marathonlb/certs/${CERT_FILE_NAME}"
  },
  "labels": {
    "PRODUCTION_READY":"True",
    "CONTAINERIZER":"Docker",
    "ZETAENV":"${APP_ROLE}"
  },
  "ports": [ 80,443,9090,9091 ],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
   "volumes": [
      { "containerPath": "/marathonlb/templates", "hostPath": "${APP_HOME}/tmeplates", "mode": "RO" },
      { "containerPath": "/marathonlb/certs", "hostPath": "$APP_CERT_LOC", "mode": "RO" }

    ]
  }
}

EOL




##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "> ${APP_HOME}/start_instance.sh"
echo ""

