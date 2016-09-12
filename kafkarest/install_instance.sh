#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
APP_LIST_ALL="1"
REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_IMG="${ZETA_DOCKER_REG_URL}/confluentrest"

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


echo "Application root is: $APP_ROOT"
echo "Application home is: $APP_HOME"


. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_${APP_ROLE}.sh



##########

echo ""
echo "List of current packages of $APP_NAME:"
echo ""
ls -ls $APP_PKG_DIR
echo ""


read -e -p "Which version of $APP_NAME do you want to use? " -i "confluent-3.0.1_conf_defaults.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi

APP_VER=$(echo -n $APP_BASE_FILE|cut -d"_" -f1)




read -e -p "What is the instance name of Kafka will this instance of ${APP_NAME} be running against: " -i "kafka${APP_ROLE}" APP_KAFKA_ID

read -e -p "What is the  instance name of schema-registry will this instance of ${APP_NAME} be running against: " -i "" APP_SCHEMA_REG

read -e -p "Please enter the service port for ${APP_ID} instance of ${APP_NAME}: " -i "28101" APP_PORT

read -e -p "Please enter the memory limit for for ${APP_ID} instance of ${APP_NAME}: " -i "768" APP_MEM

read -e -p "Please enter the cpu limit for for ${APP_ID} instance of ${APP_NAME}: " -i "1.0" APP_CPU







THOST="ZETA_SCHEMAREGISTRY_${APP_SCHEMA_REG}_HOST"
TPORT="ZETA_SCHEMAREGISTRY_${APP_SCHEMA_REG}_PORT"

eval RHOST=\$$THOST
eval RPORT=\$$TPORT
if [ "$RHOST" != "" ]; then
   APP_SCHEMA_REG_URL="schema.registry.url=http://${RHOST}:${RPORT}"
else
   APP_SCHEMA_REG_URL=""
fi


TZK="ZETA_${APP_KAFKA_ID}_ZK"
eval RZK=\$$TZK

if [ "$RZK" == "" ]; then
    echo "Could not find the ZKs for ${APP_KAFKA_ID}"
    read -e -p "Manually Specify Zookeepers for ${APP_KAFKA_ID}? (Any other key will exit): " -i "Y" MANUAL
    if [ "$MANUAL" == "Y" ]; then
        echo "Please specify ZK String for Kafka instance this instance of $APP_NAME will run against"
        read -e -p "ZK String for Kafka Instance: " -i "" RZK
        if [ "$RZK" == "" ]; then
            echo "Cannot proceed with empty ZKs"
            exit 1
        fi
    else
        echo "Exiting"
        exit 1
    fi
fi



##########
# Do instance specific things: Create Dirs, copy start files, make executable etc

# Placing def confs
mkdir -p $APP_HOME
cd $APP_HOME
cp ${APP_BASE} ./
tar zxf ${APP_VER}_conf_defaults.tgz
rm ${APP_VER}_conf_defaults.tgz

APP_CONF_DIR="${APP_HOME}/kafka-rest-conf"
APP_IMG="${ZETA_DOCKER_REG_URL}/confluentbase"


cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
chmod +x ${APP_HOME}/start_instance.sh


##########
# Highly recommended to create instance specific information to an env file for your Mesos Role
# Exampe ENV File for Docker Register V2 into sourced scripts

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

cat > ${APP_ENV_FILE} << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_ID}_HOST="${APP_ID}.\${ZETA_MARATHON_ENV}.\${ZETA_MESOS_DOMAIN}"
export ZETA_${APP_ID}_PORT="${APP_PORT}"
EOL1


echo ""
echo "Creating Config"

cat > ${APP_CONF_DIR}/kafka-rest.properties << EOF
${APP_SCHEMA_REG_URL}
zookeeper.connect=${RZK}
host.name=${APP_ID}.${APP_ROLE}.${ZETA_MARATHON_ENV}.${ZETA_MESOS_DOMAIN}
listeners=http://0.0.0.0:${APP_PORT}
EOF


cat > ${APP_CONF_DIR}/runrest.sh << EOU

#!/bin/bash


CONF_LOC="/app/${APP_VER}/etc/kafka-rest"
NEW_CONF="/conf_new"

mkdir \$NEW_CONF
cp \${CONF_LOC}/* \${NEW_CONF}/


echo "id=\$HOSTNAME" >> \${NEW_CONF}/kafka-rest.properties
EOU

chmod +x ${APP_CONF_DIR}/runrest.sh

cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd":"/app/${APP_VER}/etc/kafka-rest/runrest.sh && /app/${APP_VER}/bin/kafka-rest-start /conf_new/kafka-rest.properties",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": ${APP_PORT}, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
  "volumes": [
      {
        "containerPath": "/app/${APP_VER}/etc/kafka-rest",
        "hostPath": "${APP_CONF_DIR}",
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




