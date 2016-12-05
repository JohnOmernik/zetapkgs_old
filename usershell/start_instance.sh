#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="usershell"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh
. ${APP_HOME}/instance_include.sh

CURUSER=$(whoami)

if [ "$CURUSER" != "$ZETA_IUSER" ]; then
    echo "Must use $ZETA_IUSER: User: $CURUSER"
fi


echo "This script both installs and starts new users in the $APP_ID instance of $APP_NAME"

echo ""
read -e -p "What is the username you wish to install this instance of usershell for? " APP_USER
echo ""

APP_USER_ID=$(id $APP_USER)
if [ "$APP_USER_ID" == "" ]; then
    echo "We could not determine the ID for the user $APP_USER"
    echo "We cannot proceed if we can't figure out the user"
    exit 1
fi

APP_USER_HOME="/mapr/$CLUSTERNAME/user/$APP_USER"

if [ ! -d "$APP_USER_HOME" ]; then
    echo "A user home directory for $APP_USER should be located at $APP_USER_HOME"
    echo "We could not see that directory"
    echo "We need this to proceed"
    exit 1
fi

APP_MARATHON_FILE="${APP_HOME}/marathon/user_shell_${APP_USER}_marathon.json"

if [ -f "$APP_MARATHON_FILE" ]; then
    echo "There already is a marathon file for this instance at $APP_MARATHON_FILE"
    echo "Exiting"
    exit 1
fi

APP_USER_PATH="${APP_USER_HOME}/bin"
mkdir -p ${APP_USER_PATH}



DEF_FILES="profile nanorc bashrc"
echo ""
echo "Copying default $DEF_FILES to $APP_USER_HOME"
echo ""

for DFILE in $DEF_FILES; do
    SRCFILE="${DFILE}_template"
    DSTFILE=".${DFILE}"
    if [ -f "${APP_USER_HOME}/${DSTFILE}" ]; then
        read -e -p "${APP_USER_HOME}/${DSTFILE} exists, should we replace it with the default $DSTFILE? " -i "N" CPFILE
    else
        CPFILE="Y"
    fi

    if [ "$CPFILE" == "Y" ]; then
        sudo cp ${APP_HOME}/$SRCFILE ${APP_USER_HOME}/$DSTFILE
        sudo chown $APP_USER:zetaadm ${APP_USER_HOME}/$DSTFILE
    fi
done


read -e -p "What port should the instace of usershell for $APP_USER run on? " -i "31022" APP_PORT
APP_MAR_ID="${APP_ROLE}/${APP_ID}/${APP_USER}usershell"

echo ""
echo "You can customize your usershell env to utilize already established instances of some packages. You can skip this step if desired"
echo ""
read -e -p "Do you wish to skip instance customization? Answering anything except Y will run through some additional questions: " -i "N" SKIPCUSTOM
echo ""

if [ "$SKIPCUSTOM" != "Y" ]; then
    echo "The first package we will be offering for linking into the env is Apache Drill"
    PKG="drill"
    read -e -p "Enter instance name of $PKG you wish to associate with this usershell instance (blank if none): " PKG_ID
    read -e -p "What role is this instance of $PKG in? " PKG_ROLE

    if [ "$PKG_ID" != "" ]; then
        DRILL_PKG_HOME="/mapr/$CLUSTERNAME/zeta/$PKG_ROLE/$PKG/$PKG_ID"
        if [ ! -d "${DRILL_PKG_HOME}" ]; then
            echo "Instance home not found, skipping"
        else
            ln -s ${DRILL_PKG_HOME}/zetadrill ${APP_USER_PATH}/zetadrill
        fi
    fi

    echo "The first package we will be offering for linking into the env is Apache Spark"
    PKG="spark"
    read -e -p "Enter instance name of $PKG you wish to associate with this usershell instance (blank if none): " PKG_ID
    read -e -p "What role is this instance of $PKG in? " PKG_ROLE

    if [ "$PKG_ID" != "" ]; then
        SPARK_PKG_HOME="/mapr/$CLUSTERNAME/zeta/$PKG_ROLE/$PKG/$PKG_ID"
        if [ ! -d "${SPARK_PKG_HOME}" ]; then
            echo "Instance home not found, skipping"
        else
cat > ${APP_USER_PATH}/zetaspark << EOS
#!/bin/bash
SPARK_HOME="/spark"
cd \$SPARK_HOME
bin/pyspark
EOS
            chmod +x ${APP_USER_PATH}/zetaspark
        fi
    fi
fi


if [ -d "$SPARK_PKG_HOME" ]; then
    SPARK_HOME_SHORT=$(ls -1 ${SPARK_PKG_HOME}|grep -v "run\.sh")
    SPARK_HOME="${SPARK_PKG_HOME}/$SPARK_HOME_SHORT"

    echo "Using $SPARK_HOME for spark home"

cat > $APP_MARATHON_FILE << EOM
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd": "sed -i \"s/Port 22/Port ${APP_PORT}/g\" /etc/ssh/sshd_config && /usr/sbin/sshd -D",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
  "volumes": [
      { "containerPath": "/opt/mapr", "hostPath": "/opt/mapr", "mode": "RO"},
      { "containerPath": "/opt/mesosphere", "hostPath": "/opt/mesosphere", "mode": "RO"},
      { "containerPath": "/home/$APP_USER", "hostPath": "/mapr/$CLUSTERNAME/user/$APP_USER", "mode": "RW"},
      { "containerPath": "/home/zetaadm", "hostPath": "/mapr/$CLUSTERNAME/user/zetaadm", "mode": "RW"},
      { "containerPath": "/mapr/$CLUSTERNAME", "hostPath": "/mapr/$CLUSTERNAME", "mode": "RW"},
      { "containerPath": "/spark", "hostPath": "${SPARK_HOME}", "mode": "RW"}
    ]
  }
}
EOM
else
cat > $APP_MARATHON_FILE << EOU
{
  "id": "${APP_MAR_ID}",
  "cpus": $APP_CPU,
  "mem": $APP_MEM,
  "cmd": "sed -i \"s/Port 22/Port ${APP_PORT}/g\" /etc/ssh/sshd_config && /usr/sbin/sshd -D",
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "HOST"
    },
  "volumes": [
      { "containerPath": "/opt/mapr", "hostPath": "/opt/mapr", "mode": "RO"},
      { "containerPath": "/opt/mesosphere", "hostPath": "/opt/mesosphere", "mode": "RO"},
      { "containerPath": "/home/$APP_USER", "hostPath": "/mapr/$CLUSTERNAME/user/$APP_USER", "mode": "RW"},
      { "containerPath": "/home/zetaadm", "hostPath": "/mapr/$CLUSTERNAME/user/zetaadm", "mode": "RW"},
      { "containerPath": "/mapr/$CLUSTERNAME", "hostPath": "/mapr/$CLUSTERNAME", "mode": "RW"}
    ]
  }
}
EOU
fi

read -e -p "Do you wish to start the process now? " -i "Y" STARTAPP

if [ "$STARTAPP" == "Y" ]; then 
    echo ""
    echo "Submitting ${APP_ID} to Marathon then pausing 20 seconds to wait for start and API usability"
    echo ""
    curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_FILE} -H "Content-type: application/json"
    echo ""
    echo ""
fi


echo ""
echo ""
echo "When this instance of usershell is running, it can be accessed with the following ssh command"
echo ""
echo "ssh -p $APP_PORT ${APP_USER}@${APP_USER}usershell-${APP_ID}-${APP_ROLE}.marathon.slave.mesos"
echo ""
echo ""
