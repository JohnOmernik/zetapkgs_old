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


read -e -p "Which version of $APP_NAME do you want to use? " -i "drill-1.8.0.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi

APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo "Ports: "
read -e -p "Please enter the port for the Drill Web-ui and Rest API to run on for ${APP_ID}: " -i "20004" APP_WEB_PORT
read -e -p "Please enter the port for the Drillbit User Port for ${APP_ID}: " -i "20005" APP_USER_PORT
read -e -p "Please enter the port for the Drillbit Data port for ${APP_ID}: " -i "20006" APP_BIT_PORT
echo ""
echo "Resources"
read -e -p "Please enter the amount of Heap Space per Drillbit: " -i "4G" APP_HEAP_MEM
read -e -p "Please enter the amount of Direct Memory per Drillbit: " -i "8G" APP_DIRECT_MEM
read -e -p "Please enter the amount of memory (total) to provide as a limit to Marathon. (If Heap is 4G and Direct is 8G, 12500 is a good number here for Marathon): " -i "12500" APP_MEM
read -e -p "Please enter the amount of CPU shares to limit bits too in Marathon: " -i "4.0" APP_CPU
echo ""
echo "Misc:"
read -e -p "What is the default MapR topology for your data to use for Spill Location Volume Creation? " -i "/data/default-rack" APP_TOPO_ROOT
read -e -p "How many drillbits should we start by default: " -i "1" APP_CNT
echo ""


##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cd ${APP_HOME}

APP_CERT_LOC="${APP_HOME}/certs"

mkdir -p ${APP_HOME}
mkdir -p ${APP_HOME}/logs
mkdir -p ${APP_HOME}/logs/drillbits
mkdir -p ${APP_HOME}/logs/sqlline
mkdir -p ${APP_HOME}/logs/pids
mkdir -p ${APP_HOME}/logs/profiles

mkdir -p ${APP_HOME}/conf.std
mkdir -p ${APP_HOME}/conf.std/jars
mkdir -p ${APP_HOME}/conf.std/lib
mkdir -p ${APP_CERT_LOC}

sudo chown mapr:mapr ${APP_HOME}/logs/sqlline
sudo chmod 777 ${APP_HOME}/logs/sqlline
sudo chown -R mapr:zetaadm ${APP_HOME}/conf.std
sudo chmod -R 775 ${APP_HOME}/conf.std
sudo chown -R mapr:zetaadm ${APP_CERT_LOC}
sudo chmod -R 770 ${APP_CERT_LOC}

CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"

# Doing Java for this app because Drill uses Java
. /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_java_keystore.sh

##########
# Highly recommended to create instance specific information to an env file for your Mesos Role

cat > /mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_ID}_WEB_HOST="${APP_ID}.\${ZETA_MARATHON_ENV}.slave.\${ZETA_MESOS_DOMAIN}"
export ZETA_${APP_ID}_WEB_PORT="${APP_WEB_PORT}"
export ZETA_${APP_ID}_USER_PORT="${APP_USER_PORT}"
export ZETA_${APP_ID}_BIT_PORT="${APP_BIT_PORT}"
EOL1

echo ""
echo "Copying Files - Please wait"
echo ""

cd ${APP_HOME}

cp ${APP_BASE} ./

tar zxf ./${APP_BASE_FILE}

cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/

chmod +x ${APP_HOME}/start_instance.sh

# Get specific instance related things, 
ln -s ${APP_HOME}/conf.std ${APP_HOME}/${APP_VER}/conf
cp ${APP_HOME}/${APP_VER}/conf_orig/logback.xml ${APP_HOME}/conf.std/
cp ${APP_HOME}/${APP_VER}/conf_orig/mapr.login.conf ${APP_HOME}/conf.std/
cp ${APP_ROOT}/libjpam/* ${APP_HOME}/conf.std/lib/

cat > ${APP_HOME}/conf.std/distrib-env.sh << EOM

# MapR-specific environment settings for Drill

export HADOOP_VERSION="2.7.0"
export HADOOP_HOME=/opt/mapr/hadoop/hadoop-\${HADOOP_VERSION}

export DRILL_JAVA_OPTS="\${DRILL_JAVA_OPTS} -Djava.security.auth.login.config=/opt/mapr/conf/mapr.login.conf -Dzookeeper.sasl.client=false"
#export DRILL_LOG_DIR="/opt/mapr/drill/drill-1.8.0/logs"
#export DRILL_PID_DIR="/opt/mapr/drill/drill-1.8.0/pids"
export MAPR_IMPERSONATION_ENABLED=true
export MAPR_TICKETFILE_LOCATION=/opt/mapr/conf/mapruserticket

EOM

chmod +x ${APP_HOME}/conf.std/distrib-env.sh


cat > ${APP_HOME}/conf.std/drill-env.sh << EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CALL_SCRIPT="\$0"
MESOS_ROLE="${APP_ROLE}"
CLUSTERNAME=\$(ls /mapr)
APP_ID="${APP_ID}"
. /mapr/\${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/\${CLUSTERNAME}/zeta/kstore/env/zeta_${APP_ROLE}.sh

echo "Webhost: \${ZETA_${APP_ID}_WEB_HOST}:\${ZETA_${APP_ID}_WEB_PORT}"


export DRILL_HEAP="${APP_HEAP_MEM}"

export DRILL_MAX_DIRECT_MEMORY="${APP_DIRECT_MEM}"

# Value for the JVM -XX:MaxPermSize option for the Drillbit. Default is 512M.
export DRILLBIT_MAX_PERM="512M"

# Native library path passed to Java. Note: use this form instead
# of the old form of DRILLBIT_JAVA_OPTS="-Djava.library.path=<dir>"
# The old form is not compatible with Drill-on-YARN.
export DRILL_JAVA_LIB_PATH="${APP_HOME}/conf.std/lib/libjpam.so"

# Value for the code cache size for the Drillbit. Because the Drillbit generates
# code, it benefits from a large cache. Default is 1G.

export DRILLBIT_CODE_CACHE_SIZE="1G"

# Location to place Drill logs. Set to $DRILL_HOME/log by default.
HOSTNAME=\$(hostname -f)

export DRILL_LOG_DIR="${APP_HOME}/logs"


# Location to place the Drillbit pid file when running as a daemon using
# drillbit.sh start.
# Set to $DRILL_HOME by default.
export DRILL_PID_DIR="${APP_HOME}/logs/pids"

#export SERVER_GC_OPTS="-XX:+CMSClassUnloadingEnabled -XX:+UseG1GC "
#export DRILL_JAVA_OPTS="--XX:ReservedCodeCacheSize=1G -Ddrill.exec.enable-epoll=true -Djava.library.path=./${APP_VER}/libjpam -Djava.security.auth.login.config=/opt/mapr/conf/mapr.login.conf -Dzookeeper.sasl.client=false"

# MAPR Specifc Setting up a location for spill (this is a quick hacky version of what is done in the createTTVolume.sh)

TOPOROOT="$APP_TOPO_ROOT"
TOPO="\${TOPOROOT}/\${HOSTNAME}"

NFSROOT="/mapr/\${CLUSTERNAME}"
SPILLLOC="/var/mapr/local/\${HOSTNAME}/drillspill"

o=\$(echo \$CALL_SCRIPT|grep sqlline)
if [ "\$o" != "" ]; then
    echo "SQL Line: no SPILL Loc"
    mkdir -p \${DRILL_LOG_DIR}/sqlline/\$(whoami)
    chown \$(whoami) \${DRILL_LOG_DIR}/sqlline/\$(whoami)
    chmod 750 \${DRILL_LOG_DIR}/sqlline/\$(whoami)
    export DRILL_LOG_DIR="\${DRILL_LOG_DIR}/sqlline/\$(whoami)"
    echo "Log Dir: \$DRILL_LOG_DIR"
else
    mkdir -p ${APP_HOME}/logs/drillbits/\$HOSTNAME
    export DRILL_LOG_DIR="${APP_HOME}/logs/drillbits/\$HOSTNAME"

    export DRILL_SPILLLOC="\$SPILLLOC/\${APP_ID}"

    VOLNAME="mapr.\${HOSTNAME}.local.drillspill"

    if [ -d "\${NFSROOT}\${SPILLLOC}" ]; then
        echo "Spill Location exists: \${SPILLLOC}"
        if [ ! -d "\${NFSROOT}\${SPILLLOC}/\${APP_ID}" ]; then
            echo "Spill Root exists, but not individual \$APP_ID Directory. Adding."
            mkdir -p \${NFSROOT}\${SPILLLOC}/\${APP_ID}
        fi
    else
        echo "Need to create SPILL LOCATION: \${SPILLLOC}"
        RUNCMD="maprcli volume create -name \${VOLNAME} -path \${SPILLLOC} -rootdirperms 775 -user mapr:fc,a,dump,restore,m,d -minreplication 1 -replication 1 -topology \${TOPO} -mount 1"
        echo "\$RUNCMD"
        \$RUNCMD
        mkdir -p \${NFSROOT}\${SPILLLOC}/\${APP_ID}
    fi
fi
EOF

cat > ${APP_HOME}/conf.std/drill-override.conf << EOF2
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#  This file tells Drill to consider this module when class path scanning.
#  This file can also include any supplementary configuration information.
#  This file is in HOCON format, see https://github.com/typesafehub/config/blob/master/HOCON.md for more information.

# See 'drill-override-example.conf' for example configurations

drill.exec: {
  cluster-id: \${ZETA_${APP_ID}_ENV},
  http.ssl_enabled: true,
  http.port: \${ZETA_${APP_ID}_WEB_PORT},
  rpc.user.server.port: \${ZETA_${APP_ID}_USER_PORT},
  rpc.bit.server.port: \${ZETA_${APP_ID}_BIT_PORT},
  sys.store.provider.zk.blobroot: "maprfs:///${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}/logs/profiles",
  sort.external.spill.directories: [ \${?DRILL_SPILLLOC} ],
  sort.external.spill.fs: "maprfs:///",
  zk.connect: \${ZETA_ZKS},
  zk.root: "${APP_ID}",
  impersonation: {
    enabled: true,
    max_chained_user_hops: 3
  },
  security.user.auth {
         enabled: true,
         packages += "org.apache.drill.exec.rpc.user.security",
         impl: "pam",
         pam_profiles: [ "sudo", "login" ]
   }
},
javax.net.ssl {
  keyStore: "${APP_KEYSTORE}",
  keyStorePassword: "${KEYSTOREPASS}",
  trustStore: "${APP_TRUSTSTORE}",
  trustStorePassword: "${TRUSTSTOREPASS}"
}
EOF2


sudo chown zetaadm:zeta${APP_ROLE}zeta ${APP_HOME}/conf.std/drill-override.conf
sudo chmod 660 ${APP_HOME}/conf.std/drill-override.conf

cat > ${APP_HOME}/zetadrill << EOF3
#!/bin/bash

# Setup Drill Locations Versions
DRILL_LOC="${APP_HOME}"
DRILL_VER="${APP_VER}"
DRILL_BIN="/bin/sqlline"

#This is your Drill url
URL="jdbc:drill:zk:${ZETA_ZKS}/${APP_ID}"

#Location for the prop file. (Should be user's home directoy)
DPROP=~/prop\$\$

# Secure the File
touch "\$DPROP"
chmod 600 "\$DPROP"

# Get username from user
printf "Please enter Drill Username: "
read USER

# Turn of Terminal Echo
stty -echo
# Get Password from User
printf "Please enter Drill Password: "
read PASS
# Turn Echo back on 
stty echo
printf "\n"

# Write properties file for Drill
cat >> "\$DPROP" << EOL
user=\$USER
password=\$PASS
url=\$URL
EOL


# Exectue Drill connect with properties file. After 10 seconds, the command will delete the prop file. Note this may result in race condition. 
# 10 seconds SHOULD be enough. 
(sleep 10; rm "\$DPROP") & \${DRILL_LOC}/\${DRILL_VER}\${DRILL_BIN} \${DPROP}

EOF3

chmod +x ${APP_HOME}/zetadrill

cat > ${APP_MARATHON_FILE} << EOF4
{
"id": "${APP_ROLE}/${APP_ID}",
"cmd": "./${APP_VER}/bin/drillbit.sh run",
"cpus": ${APP_CPU},
"mem": ${APP_MEM},
"instances": ${APP_CNT},
"labels": {
    "PRODUCTION_READY":"True",
    "ZETAENV":"${APP_ROLE}",
    "CONTAINERIZER":"Mesos"
},
"env": {
"JAVA_HOME": "$JAVA_HOME",
"DRILL_VER": "${APP_VER}",
"MESOS_ROLE": "${APP_ROLE}",
"APP_ID": "${APP_ID}",
"DRILL_CONF_DIR":"${APP_HOME}/conf.std"
},
"ports":[],
"user": "mapr",
"uris": ["file://${APP_BASE}"],
"constraints": [["hostname", "UNIQUE"]]
}
EOF4


##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "> ${APP_HOME}/start_instance.sh"
echo ""

