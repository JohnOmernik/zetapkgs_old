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


read -e -p "Which version of $APP_NAME do you want to use? " -i "zeppelin-0.7.0-SNAPSHOT.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi
APP_TGZ=$APP_BASE_FILE
APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
##########
# Note: Template uses Docker Registery as example, you will want to change this
# Get instance Specifc variables from user.
read -e -p "Please enter the port for this instance of Zeppelin: " -i "43080" APP_PORT
read -e -p "Please enter the total memory usage for this instance of ${APP_NAME}: " -i "2048" APP_TOTAL_MEM
read -e -p "Please enter the memory usage for just $APP_NAME. This should be less then $APP_TOTAL_MEM: " -i "1024m" APP_MEM
read -e -p "Please enter the CPU usage for this instance of ${APP_NAME}: " -i "2.0" APP_CPU
read -e -p "Please enter the Username of the primary user of this instance of ${APP_NAME}: " -i "zetaadm" APP_USER



##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cd ${APP_HOME}

echo "Creating User Specific Directories"
APP_USER_DIR="/mapr/${CLUSTERNAME}/user/${APP_USER}"
APP_USER_ID_DIR="/mapr/${CLUSTERNAME}/user/${APP_USER}/${APP_NAME}/${APP_ID}"
echo "Getting UID"

APP_UID=$(id -u ${APP_USER})
echo "UID: $APP_UID"

if [ ! -d "${APP_USER_DIR}" ]; then
    echo "The user provided, ${APP_USER}, does not appear to have a home directory:"
    echo "${APP_USER_DIR}"
    echo "Thus you can't install an instance here"
    rm -rf ${APP_HOME}
    exit 0
fi
if [ -d "${APP_USER_ID_DIR}" ]; then
    echo "An instance directory for that user already exists"
    echo "Will not overwrite, please choose a different name or remove the directory"
    echo "${APP_USER_ID_DIR}"
    rm -rf ${APP_HOME}
    exit 0
fi



cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
chmod +x ${APP_HOME}/start_instance.sh

echo "Making Dirs"
sudo mkdir -p ${APP_USER_ID_DIR}
sudo mkdir -p ${APP_USER_ID_DIR}/notebooks
sudo mkdir -p ${APP_USER_ID_DIR}/logs
sudo mkdir -p ${APP_USER_ID_DIR}/conf
echo "Untaring TGZ"
sudo tar zxf ${APP_PKG_DIR}/${APP_TGZ} -C ${APP_USER_ID_DIR}
echo "Setting up Conf"

sudo cp ${APP_USER_ID_DIR}/${APP_VER}/conf/* ${APP_USER_ID_DIR}/conf/
sudo cp ${APP_USER_ID_DIR}/conf/zeppelin-site.xml.template ${APP_USER_ID_DIR}/conf/zeppelin-site.xml

sudo sed -i -r "s/<value>8080<\/value>/<value>${APP_PORT}<\/value>/" ${APP_USER_ID_DIR}/conf/zeppelin-site.xml
sudo sed -i -r "s@<value>local-repo</value>@<value>/logs/local-repo</value>@" ${APP_USER_ID_DIR}/conf/zeppelin-site.xml

sudo sed -i -r "s/org\.apache\.zeppelin\.spark\.PySparkInterpreter/org.apache.zeppelin.spark.PySparkInterpreter/" ${APP_USER_ID_DIR}/conf/zeppelin-site.xml

sudo cp ${APP_USER_ID_DIR}/conf/zeppelin-env.sh.template ${APP_USER_ID_DIR}/conf/zeppelin-env.sh

echo "Setting Permissions"
sudo chown -R ${APP_USER}:zeta${APP_ROLE}data ${APP_USER_DIR}/zeppelin

sudo cat > ${APP_USER_ID_DIR}/user_config.sh << EOU
#!/bin/bash

CLUSTERNAME=$(ls /mapr)
MESOS_ROLE="${APP_ROLE}"
APP_UP="${APP_UP}"
APP_ID="${APP_ID}"

. /mapr/\$CLUSTERNAME/zeta/kstore/env/zeta_${APP_ROLE}.sh

RUSER=\$(whoami)




echo "This script provides you the information to setup your interpreters in Zeppelin"
echo ""
echo "First Drill"
echo "Based on roles, here are the options for Drill instances to connect to:"
echo ""
ls -ls /mapr/\$CLUSTERNAME/zeta/\${MESOS_ROLE}/drill/
echo ""
echo ""
read -e -p "Please enter the name of the Drill Role to choose}: " -i "drill\${MESOS_ROLE}" DRILL_ID
echo ""
echo ""
echo "on the Interpreters page, scroll to jdbc"
echo ""
echo "Here, set the following options and press save:"
echo ""
echo "default.user: \${RUSER}"
echo "default.password: %ENTERYOURPASSWORD%"
echo "default.url: jdbc:drill:zk=${ZETA_ZKS}/\%DRILL_ID%\/%DRILL_ID%"
echo "default.driver: org.apache.drill.jdbc.Driver"
echo "common.max_count: 10000"
echo ""
echo ""
echo "While passwords show up in plain text in the web there is some security around them in the back ground"
echo ""
echo ""

EOU
sudo chmod +x ${APP_USER_ID_DIR}/user_config.sh
sudo chown -R ${APP_USER}:zeta${APP_ROLE}data ${APP_USER_DIR}/zeppelin



##########
# Highly recommended to create instance specific information to an env file for your Mesos Role
# Exampe ENV File for Docker Register V2 into sourced scripts

cat > /mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ID="${APP_ID}"
export ZETA_${APP_ID}_PORT="${APP_PORT}"
export ZETA_${APP_ID}_USER="${APP_USER}"
export ZETA_${APP_ID}_URL="${APP_ID}.${APP_ROLE}.\${ZETA_MARATHON_ENV}.\${ZETA_MESOS_DOMAIN}:${APP_PORT}"
EOL1

##########
# After it's written we source itSource the script!
. /mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh


##########
# Create a marathon file if appropriate in teh ${APP_HOME} directory
# This actually updates the interpreter json so root or the owner can change
cat > ${APP_MARATHON_FILE} << EOF
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_TOTAL_MEM},
  "instances": 1,
  "cmd":"su -c /zeppelin/bin/zeppelin.sh ${APP_USER}",
  "labels": {
   "PRODUCTION_READY":"True", "CONTAINERIZER":"Docker", "ZETAENV":"${APP_ROLE}"
  },
"env": {
"ZEPPELIN_CONF_DIR":"/conf",
"ZEPPELIN_NOTEBOOK_DIR":"/notebooks",
"ZEPPELIN_HOME":"/zeppelin",
"ZEPPELIN_LOG_DIR":"/logs",
"ZEPPELIN_MEM":"-Xms${APP_MEM} -Xmx${APP_MEM} -XX:MaxPermSize=512m",
"ZEPPELIN_PID_DIR":"/logs",
"ZEPPELIN_INTERPRETER_LOCALREPO":"/logs/local-repo",
"ZEPPELIN_DEP_LOCALREPO":"/logs/dep-repo",
"MASTER":"mesos://leader.mesos:5050",
"SPARK_HOME":"NotSet",
"HADOOP_CONF_DIR":"NotSet",
"ZEPPELIN_SPARK_CONCURRENTSQL":"true",
"SPARK_APP_NAME":"zeppelinspark-$APP_ID",
"DEBUG":"0"
},
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${ZETA_DOCKER_REG_URL}/zep_run",
      "network": "HOST"
    },
  "volumes": [
      {
        "containerPath": "/zeppelin",
        "hostPath": "${APP_USER_ID_DIR}/${APP_VER}",
        "mode": "RO"
      },
      {
        "containerPath": "/logs",
        "hostPath": "${APP_USER_ID_DIR}/logs",
        "mode": "RW"
      },
      {
        "containerPath": "/notebooks",
        "hostPath": "${APP_USER_ID_DIR}/notebooks",
        "mode": "RW"
      },
      {
        "containerPath": "/conf",
        "hostPath": "${APP_USER_ID_DIR}/conf",
        "mode": "RW"
      }
    ]
  }
}

EOF


#      {
#        "containerPath": "/mapr/${CLUSTERNAME}",
#        "hostPath": "/mapr/${CLUSTERNAME}",
#        "mode": "RW"
#      },


###### WHERE I AM



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



