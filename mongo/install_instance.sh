#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}:3.3" # Update this when new versions come out

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


echo "Application root is: $APP_ROOT"
echo "Application home is: $APP_HOME"

mkdir -p $APP_HOME
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/
APP_MARATHON_FILE="${APP_HOME}/marathon.json"

APP_DATA_DIR="$APP_HOME/mongo_data"
APP_CONFDB_DIR="$APP_HOME/mongo_configdb"
APP_CONF_DIR="$APP_HOME/mongo_conf"
APP_LOG_DIR="$APP_HOME/mongo_logs"



mkdir -p $APP_DATA_DIR
mkdir -p $APP_CONF_DIR
mkdir -p $APP_CONFDB_DIR
mkdir -p $APP_LOG_DIR
mkdir -p ${APP_HOME}/lock
sudo chmod 770 $APP_DATA_DIR
sudo chmod 770 $APP_CONF_DIR
sudo chmod 770 $APP_CONFDB_DIR
sudo chmod 770 $APP_LOG_DIR


read -e -p "Please enter the CPU to use with mongo: " -i "2.0" APP_MAR_CPU
echo ""
read -e -p "Please enter the max cache size (this should be under the Marathon amount (Which is specified in MB) and this  specified in GB: " -i "2" APP_MEM_CACHE
echo ""
read -e -p "Please enter the Marathon Memory limit to use with mongo: " -i "2560" APP_MAR_MEM
echo ""
read -e -p "Please enter a port to use with mongo: " -i "30122" APP_PORT
echo ""


cat > /mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh << EOL1
#!/bin/bash
export ZETA_${APP_NAME}_${APP_ID}_PORT="${APP_PORT}"
EOL1


cat > ${APP_CONF_DIR}/mongod.conf << EOL5
systemLog:
   destination: file
   verbosity: 1
   timeStampFormat: iso8601-utc
   path: /data/log/mongod.log
   logAppend: true
storage:
   dbPath: /data/db
   engine: wiredTiger
   directoryPerDB: true
   journal:
      enabled: true
   wiredTiger:
      engineConfig:
         cacheSizeGB: $APP_MEM_CACHE
operationProfiling:
   slowOpThresholdMs: 100
   mode: off # Set to slowOp to check things out
processManagement:
   fork: false
net:
   port: 27017
setParameter:
   enableLocalhostAuthBypass: false
EOL5


cat  > ${APP_HOME}/lock/run.sh << EOL2
#!/bin/bash
chmod +x /entrypoint.sh
/entrypoint.sh --config /data/conf/mongod.conf
EOL2
chmod +x ${APP_HOME}/lock/run.sh

cat > ${APP_HOME}/lock/lockfile.sh << EOL3
#!/bin/bash

#The location the lock will be attempted in
LOCKROOT="/lock"
LOCKDIRNAME="lock"
LOCKFILENAME="mylock.lck"

#This is the command to run if we get the lock.
RUNCMD="/lock/run.sh"

#Number of seconds to consider the Lock stale, this could be application dependent.
LOCKTIMEOUT=60
SLEEPLOOP=30

LOCKDIR=\${LOCKROOT}/\${LOCKDIRNAME}
LOCKFILE=\${LOCKDIR}/\${LOCKFILENAME}



if mkdir "\${LOCKDIR}" &>/dev/null; then
    echo "No Lockdir. Our lock"
    # This means we created the dir!
    # The lock is ours
    # Run a sleep loop that puts the file in the directory
    while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
    #Now run the real shell scrip
    \$RUNCMD
else
    #Pause to allow another lock to start
    sleep 1
    if [ -e "\$LOCKFILE" ]; then
        echo "lock dir and lock file Checking Stats"
        CURTIME=\`date +%s\`
        FILETIME=\`cat \$LOCKFILE\`
        DIFFTIME=\$((\$CURTIME-\$FILETIME))
        echo "Filetime \$FILETIME"
        echo "Curtime \$CURTIME"
        echo "Difftime \$DIFFTIME"

        if [ "\$DIFFTIME" -gt "\$LOCKTIMEOUT" ]; then
            echo "Time is greater then Timeout We are taking Lock"
            # We should take the lock! First we remove the current directory because we want to be atomic
            rm -rf \$LOCKDIR
            if mkdir "\${LOCKDIR}" &>/dev/null; then
                while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
                \$RUNCMD
            else
                echo "Cannot Establish Lock file"
                exit 1
            fi
        else
            # The lock is not ours.
            echo "Cannot Estblish Lock file - Active "
            exit 1
        fi
    else
        # We get to be the locker. However, we need to delete the directory and recreate so we can be all atomic about
        rm -rf \$LOCKDIR
        if mkdir "\${LOCKDIR}" &>/dev/null; then
            while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
            \$RUNCMD
        else
            echo "Cannot Establish Lock file - Issue"
            exit 1
        fi
    fi
fi
EOL3
chmod +x ${APP_HOME}/lock/lockfile.sh


cat > $APP_MARATHON_FILE << EOL
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cmd": "/lock/lockfile.sh",
  "cpus": ${APP_MAR_CPU},
  "mem": ${APP_MAR_MEM},
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
        { "containerPort": 27017, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/data/db", "hostPath": "${APP_DATA_DIR}", "mode": "RW" },
      { "containerPath": "/data/configdb", "hostPath": "${APP_CONFDB_DIR}", "mode": "RW" },
      { "containerPath": "/data/conf", "hostPath": "${APP_CONF_DIR}", "mode": "RO" },
      { "containerPath": "/data/log", "hostPath": "${APP_LOG_DIR}", "mode": "RW" },
      { "containerPath": "/lock", "hostPath": "${APP_HOME}/lock", "mode": "RW" }
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




