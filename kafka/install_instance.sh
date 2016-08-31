#!/bin/bash
CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
APP_LIST_ALL="1"

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

APP_NAME=$(basename "$MYDIR")

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh

echo ""
echo "List of current packages of $APP_NAME:"
echo ""
ls -ls $APP_PKG_DIR
echo ""


read -e -p "Which version of $APP_NAME do you want to use? " -i "kafka-mesos-0.9.5.1-kafka_2.10-0.10.0.1.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi
APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")


read -e -p "Please enter the port for ${APP_NAME} API to run on for ${APP_ID}: " -i "21000" APP_PORT

APP_MEM="768" # This could be read in if you want the user to have control for your app
APP_CPU="1" # This could be read in you want the user to have control for your app

##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cd ${APP_HOME}

cp ${APP_BASE} ./

tar zxf ./${APP_BASE_FILE}

cp ${APP_ROOT}/start_instance.sh ${APP_HOME}

chmod +x ${APP_HOME}/start_instance.sh

JAVA_TGZ="mesos-java.tgz"
cd $JAVA_HOME
tar zcf ${APP_HOME}/$JAVA_TGZ ./jre
cd ${APP_HOME}
mv ./$JAVA_TGZ ./kafka-mesos/

##########
# Highly recommended to create instance specific information to an env file for your Mesos Role
# Exampe ENV File for Docker Register V2 into sourced scripts

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

cat > $APP_ENV_FILE << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_NAME}_${APP_ID}_ZK="${ZETA_ZKS}/${APP_ID}"
export ZETA_${APP_NAME}_${APP_ID}_API_PORT="${APP_PORT}"
EOL1

##########
# After it's written we source it!
. $APP_ENV_FILE

##########
# Get specific instance related things, 
APP_USER="zetasvc$APP_ROLE"

cat > ${APP_HOME}/kafka-mesos/kafka-mesos.properties << EOF
# Scheduler options defaults. See ./kafka-mesos.sh help scheduler for more details
debug=false

framework-name=${APP_ID}

master=leader.mesos:5050

user=$APP_USER

storage=zk:/kafka-mesos

jre=${JAVA_TGZ}
# Need the /kafkaprod as the chroot for zk
zk=${ZETA_ZKS}/${APP_ID}

# Need different port for each framework
api=http://${APP_ID}.${APP_ROLE}.${ZETA_MARATHON_ENV}.${ZETA_MESOS_DOMAIN}:${APP_PORT}

#principal=${ROLE_PRIN}

#secret=${ROLE_PASS}

EOF
APP_TGZ="${APP_ID}-runnable.tgz"
tar zcf ./$APP_TGZ kafka-mesos/
rm ${APP_BASE_FILE}




##########
# Create a marathon file if appropriate in teh ${APP_HOME} directory

APP_MARATHON_FILE="${APP_HOME}/$APP_ID.marathon"
cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "instances": 1,
  "cpus": ${APP_CPU},
  "cmd": "export PATH=\`pwd\`/jre/bin:\$PATH && cd kafka-mesos && ./kafka-mesos.sh scheduler kafka-mesos.properties",
  "user": "${APP_USER}",
  "mem": ${APP_MEM},
  "labels": {
   "CONTAINERIZER":"Mesos"
  },
  "env": {
    "JAVA_LIBRARY_PATH": "/opt/mesosphere/lib",
    "MESOS_NATIVE_JAVA_LIBRARY": "/opt/mesosphere/lib/libmesos.so",
    "LD_LIBRARY_PATH": "/opt/mesosphere/lib",
    "JAVA_HOME": "jre"
  },
  "uris": ["file://${APP_HOME}/${APP_TGZ}", "file://${APP_HOME}/kafka-mesos/${JAVA_TGZ}"]
}
EOL


##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "> ${APP_HOME}/start_instance.sh"
echo ""
echo ""

