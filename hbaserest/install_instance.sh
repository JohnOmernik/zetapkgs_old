#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
APP_LIST_ALL="1"
REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_IMG="${ZETA_DOCKER_REG_URL}/hbaserestbase"

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


read -e -p "Which version of $APP_NAME do you want to use? " -i "hbase-1.1.1.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi
APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")





##########

read -e -p "Please enter the port for ${APP_NAME} info service: " -i "27005" APP_INFO_PORT
read -e -p "Please enter the port for ${APP_NAME} REST API: " -i "27000" APP_PORT
read -e -p "Please enter the amount of memory to use for the $APP_ID instance of $APP_NAME: " -i "1024" APP_MEM
read -e -p "Please enter the amount of cpu to use for the $APP_ID instance of $APP_NAME: " -i "1.0" APP_CPU

read -e -p "What username will this instance of hbaserest run as. Note: it must have access to the tables you wish provide via REST API: " -i "zetasvc${APP_ROLE}" APP_USER
echo ""
echo "The next prompt will ask you for the root location for hbase table namespace mapping"
echo "Due to how maprdb and hbase interace, you need to provide a MapR-FS directory, where, within, are the tables this hbase rest API will serve"
echo ""
echo "For example, if in the path: /data/prod/myhbasetables,  you have two tables, tab1 and tab2, you want served by this HBASE rest instance"
echo "Then at the prompt for directory root, pot in /data/prod/myhbasetables"
echo ""
echo "This can be changed in the conf directory (the hbase-site.xml) for this instance"

read -e -p "What root directory should we use to identify hbase tables? :" -i "/apps/${APP_ROLE}/myhbasetables" APP_TABLE_ROOT



##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/

chmod +x ${APP_HOME}/start_instance.sh

tar zxf ${APP_BASE} -C ${APP_HOME}/

mkdir -p ${APP_HOME}/logs

mv ${APP_HOME}/${APP_VER}/conf_orig ${APP_HOME}/conf

rm -rf ${APP_HOME}/${APP_VER}

cat > ${APP_HOME}/conf/docker_start.sh << EOF4
#!/bin/bash
export HBASE_LOGFILE="hbaserest-\$HOST-\$HOSTNAME.log"
env
/${APP_VER}/bin/hbase rest start -p 8000 --infoport 8005
EOF4
chmod +x ${APP_HOME}/conf/docker_start.sh


##########
# Highly recommended to create instance specific information to an env file for your Mesos Role

APP_ENV_FILE="/mapr/$CLUSTERNAME/zeta/kstore/env/env_${APP_ROLE}/${APP_NAME}_${APP_ID}.sh"

cat > ${APP_ENV_FILE} << EOL1
#!/bin/bash
export ZETA_${APP_ID}_ENV="${APP_ID}"
export ZETA_${APP_ID}_INFO_PORT="${APP_INFO_PORT}"
export ZETA_${APP_ID}_PORT="${APP_PORT}"
export ZETA_${APP_ID}_HOST="${APP_ID}.${APP_ROLE}.${ZETA_MARATHON_ENV}.${ZETA_MESOS_DOMAIN}"
EOL1

ZK=$(echo $ZETA_ZKS|cut -d"," -f1)
ZK_PORT=$(echo $ZK|cut -d":" -f2)
ZKS_NOPORT=$(echo $ZETA_ZKS|sed "s/:${ZK_PORT}//g")

cat > ${APP_HOME}/conf/hbase-site.xml << EOFCONF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
/**
 * Copyright 2010 The Apache Software Foundation
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
-->
<configuration>

  <property>
    <name>hbase.rootdir</name>
    <value>maprfs:///hbase</value>
  </property>

  <property>
<name>hbase.cluster.distributed</name>
<value>true</value>
  </property>

  <property>
<name>hbase.zookeeper.quorum</name>
<value>${ZKS_NOPORT}</value>
  </property>

  <property>
<name>hbase.zookeeper.property.clientPort</name>
<value>${ZK_PORT}</value>
  </property>

  <property>
    <name>dfs.support.append</name>
    <value>true</value>
  </property>

  <property>
    <name>hbase.fsutil.maprfs.impl</name>
    <value>org.apache.hadoop.hbase.util.FSMapRUtils</value>
  </property>
  <property>
    <name>hbase.regionserver.handler.count</name>
    <value>30</value>
    <!-- default is 25 -->
  </property>

  <!-- uncomment this to enable fileclient logging
  <property>
    <name>fs.mapr.trace</name>
    <value>debug</value>
  </property>
  -->

  <!-- Allows file/db client to use 64 threads -->
  <property>
    <name>fs.mapr.threads</name>
    <value>64</value>
  </property>


  <property>
    <name>mapr.hbase.default.db</name>
    <value>maprdb</value>
  </property>

  <property>
    <name>hbase.table.namespace.mappings</name>
        <value>*:${APP_TABLE_ROOT}/</value> 
  </property>

</configuration>
EOFCONF


cat > $APP_MARATHON_FILE << EOF
{
  "id": "${APP_ROLE}/${APP_ID}",
  "cpus": ${APP_CPU},
  "mem": ${APP_MEM},
  "instances": 1,
  "cmd":"su -c /$APP_VER/conf/docker_start.sh ${APP_USER}",
  "labels": {
   "PRODUCTION_READY":"True", "CONTAINERIZER":"Docker", "ZETAENV":"${APP_ROLE}"
  },
  "env": {
    "HBASE_HOME": "/${APP_VER}",
    "HADOOP_HOME": "/opt/mapr/hadoop/hadoop-2.7.0",
    "HBASE_LOG_DIR": "/${APP_VER}/logs",
    "HBASE_ROOT_LOGGER": "INFO,RFA",
    "HBASE_CLASSPATH_PREFIX":"/${APP_VER}/lib/*:/opt/mapr/lib/*",
    "JAVA_HOME": "/usr/lib/jvm/java-8-openjdk-amd64"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 8000, "hostPort": ${APP_PORT}, "servicePort": 0, "protocol": "tcp"},
        { "containerPort": 8005, "hostPort": ${APP_INFO_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
  "volumes": [
      {
        "containerPath": "/${APP_VER}/logs",
        "hostPath": "${APP_HOME}/logs",
        "mode": "RW"
      },
      {
        "containerPath": "/opt/mapr",
        "hostPath": "/opt/mapr",
        "mode": "RO"
      },
      {
        "containerPath": "/${APP_VER}/conf",
        "hostPath": "${APP_HOME}/conf",
        "mode": "RO"
      }
    ]
  }
}
EOF


echo ""
echo ""
echo "${APP_NAME} Instance created at ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/start_instance.sh"
echo ""
echo ""




