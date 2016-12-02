#!/bin/bash

CLUSTERNAME=$(ls /mapr)
. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh
REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_LIST_ALL="0"

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh




echo ""
echo "List of current packages of $APP_NAME:"
echo ""
ls -ls $APP_PKG_DIR
echo ""


read -e -p "Which version of $APP_NAME do you want to use? " -i "spark-2.0.2-bin-without-hadoop.tgz" APP_BASE_FILE

APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi

APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")


read -e -p "Which docker image do you want to use for executors? " -i "${ZETA_DOCKER_REG_URL}/spark:2.0.2" APP_EXEC_IMG
sudo docker pull $APP_EXEC_IMG
DCK_CHK=$(sudo docker images --format "table {{.Repository}}:{{.Tag}}"|grep "$APP_EXEC_IMG")
if [ "$DCK_CHK" == "" ]; then
    echo "We tried to pull the executor image $APP_EXEC_IMG and it didn't work, please ensure it's properly built"
    exit 1
fi
echo ""
echo ""

echo "Unpacking TGZ File to Instance Root"
tar zxf $APP_BASE -C $APP_HOME

cat > $APP_HOME/run.sh << EOL
#!/bin/bash

IMG="$APP_EXEC_IMG"

SPARK="-v=${APP_HOME}/${APP_VER}:/spark:ro"

MAPR="-v=/opt/mapr:/opt/mapr:ro"
MESOSLIB="-v=/opt/mesosphere:/opt/mesosphere:ro"
NET="--net=host"

U="--user nobody"


sudo docker run -it --rm \$U \$NET \$SPARK \$MAPR \$MESOSLIB \$IMG /bin/bash
EOL

chmod +x $APP_HOME/run.sh

# This should be read in at instance install time. Hardcoding for now
MAPR_HOME="/opt/mapr"
HADOOP_HOME="${MAPR_HOME}/hadoop/hadoop-2.7.0"

# These are Calculated for a MapR install
MAPR_FS_LIB=$(ls -1 ${MAPR_HOME}/lib/maprfs-*|grep -v diagnostic)

cat > ${APP_HOME}/${APP_VER}/conf/spark-env.sh << EOE
#!/usr/bin/env bash
export JAVA_LIBRARY_PATH=/opt/mesosphere/lib
export MESOS_NATIVE_JAVA_LIBRARY=/opt/mesosphere/lib/libmesos.so
export LD_LIBRARY_PATH=/opt/mesosphere/lib
export JAVA_HOME=/opt/mesosphere/active/java/usr/java

export HADOOP_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=\${HADOOP_HOME}/etc/hadoop
MAPR_HADOOP_CLASSPATH=\`\${HADOOP_HOME}/bin/hadoop classpath\`:\`ls $MAPR_HOME/lib/slf4j-log*\`:
MAPR_HADOOP_JNI_PATH=\`\${HADOOP_HOME}/bin/hadoop jnipath\`
export SPARK_LIBRARY_PATH=\$MAPR_HADOOP_JNI_PATH
MAPR_SPARK_CLASSPATH="\$MAPR_HADOOP_CLASSPATH"
SPARK_DIST_CLASSPATH=\$MAPR_SPARK_CLASSPATH
# Security status
source /opt/mapr/conf/env.sh
if [ "\$MAPR_SECURITY_STATUS" = "true" ]; then
SPARK_SUBMIT_OPTS="\$SPARK_SUBMIT_OPTS -Dmapr_sec_enabled=true"
fi

EOE

SPARK_DRIVER_MEM="512m"
SPARK_EXECUTOR_MEM="4096m"





cat > ${APP_HOME}/${APP_VER}/conf/spark-defaults.conf << EOC
spark.master                       mesos://leader.mesos:5050

spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.driver.memory              $SPARK_DRIVER_MEM
spark.executor.memory            $SPARK_EXECUTOR_MEM

spark.sql.hive.metastore.sharedPrefixes com.mysql.jdbc,org.postgresql,com.microsoft.sqlserver,oracle.jdbc,com.mapr.fs.shim.LibraryLoader,com.mapr.security.JNISecurity,com.mapr.fs.jni

spark.executor.extraClassPath   `ls $HADOOP_HOME/share/hadoop/yarn/hadoop-yarn-common-*`:`ls -1 ${MAPR_HOME}/lib/maprfs-*|grep -v diagnostic`

spark.mesos.executor.docker.image $APP_EXEC_IMG

spark.home  /spark

spark.mesos.executor.docker.volumes ${APP_HOME}/${APP_VER}:/spark:ro,/opt/mapr:/opt/mapr:ro,/opt/mesosphere:/opt/mesosphere:ro

EOC

echo ""
echo "Spark Instance $APP_ID is installed at $APP_HOME"
echo "You can run a docker container with all info via $APP_HOME/run.sh"
echo "Once inside this container:"
echo "1. Authenticate as a user who has access to the data (example: su zetasvc${APP_ROLE})"
echo "2. cd /spark"
echo "3. bin/pyspark"
echo ""
echo "This is a basic/poc install, changes can be made via the conf files"
echo ""
