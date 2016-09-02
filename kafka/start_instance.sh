#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="kafka"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh

CURUSER=$(whoami)

if [ "$CURUSER" != "$ZETA_IUSER" ]; then
    echo "Must use $ZETA_IUSER: User: $CURUSER"
fi

PATH=$PATH:$JAVA_HOME/bin

CREDS="/home/$ZETA_IUSER/creds/creds.txt"
if [ ! -f "$CREDS" ]; then
    echo "Can't find Creds file, exiting"
    exit
fi

HOST=$(echo $ZETA_CLDBS|cut -d"," -f1|cut -d":" -f1)
WEBHOST="$HOST:8443"
TFILE="/tmp/netrc.tmp"

touch $TFILE
chown $ZETA_IUSER:$ZETA_IUSER $TFILE
chmod 600 $TFILE
cat > $TFILE << EOF
machine $HOST login $(cat $CREDS|grep mapr|cut -d":" -f1) password $(cat $CREDS|grep mapr|cut -d":" -f2)
EOF



BASE_REST="https://$WEBHOST/rest"

CURL_GET_BASE="/opt/mesosphere/bin/curl -k --netrc-file $TFILE $BASE_REST"



echo ""
echo "Submitting ${APP_ID} to Marathon then pausing 20 seconds to wait for start and API usability"
echo ""

curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_HOME}/${APP_ID}.marathon -H "Content-type: application/json"
echo ""
echo ""

sleep 20
cd ${APP_HOME}
cd ./kafka-mesos

APP_CHECK=$(./kafka-mesos.sh broker list)

while [ "${APP_CHECK}" != "no brokers" ]; do
    echo "We did not connect to the service, or brokers already exist"
    echo ""
    echo "Result of previous Broker Check: ${APP_CHECK}"
    read -e -p "Try again? "-i "Y" THEREISNOTRY

    if [ "$THEREISNOTRY" == "Y" ]; then
        APP_CHECK=$(./kafka-mesos.sh broker list)
    else
       echo "Exiting"
       exit 1
    fi
done
echo "We are good to proceed in adding brokers"

echo "What setting should we use for heap space for each broker (in MB)?"
read -e -p "Heap Space: " -i "1024" BROKER_HEAP
echo ""
echo "How much memory per broker (separate from heap) should we use (in MB)?"
read -e -p "Broker Memory: " -i "2048" BROKER_MEM
echo ""
echo "How many CPU vCores should we use per broker?"
read -e -p "Broker CPU(s): " -i "1" BROKER_CPU
echo ""
echo "How many kafka brokers do you want running in this instance?"
read -e -p "Number of Brokers: " -i "3" BROKER_COUNT

echo "You want ${BROKER_COUNT} broker(s) running, each using ${BROKER_HEAP} mb of heap, ${BROKER_MEM} mb of memory, and ${BROKER_CPU} cpu(s)"
echo ""
read -e -p "Is this summary correct? (Y/N): " -i "Y" ANS

if [ "${ANS}" != "Y" ]; then
    echo "You did not answer Y so something is not right"
    echo "Exiting"
    exit 1
fi


mkdir -p ${APP_HOME}/brokerdata

APP_USER="zetasvc${APP_ROLE}"
APP_GROUP="zeta${APP_ROLE}${APP_DIR}"
for X in $(seq 1 $BROKER_COUNT)
do
    BROKER="broker${X}"
    echo "Adding ${BROKER}..."
    VOL="${APP_DIR}.${APP_ROLE}.${APP_ID}.${BROKER}"
    MNT="/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}/brokerdata/${BROKER}"
    NFSLOC="${APP_HOME}/brokerdata/${BROKER}/"
 #   sudo maprcli volume create -name $VOL -path $MNT -rootdirperms 775 -user zetaadm:fc,a,dump,restore,m,d


    CMD="$CURL_GET_BASE/volume/create?name=${VOL}&path=${MNT}&rootdirperms=775&user=zetaadm:fc,a,dump,restore,m,d%20mapr:fc,a,dump,restore,m,d%20${APP_USER}:fc,a,dump,restore,m,d&ae=${APP_USER}"
    $CMD
    echo ""
    T=""
    while [ "$T" == "" ]; do
        sleep 1
        T=$(ls -1 ${APP_HOME}/brokerdata|grep $BROKER)
    done
    sudo chown ${APP_USER}:${APP_GROUP} $NFSLOC

    ./kafka-mesos.sh broker add $X
    ./kafka-mesos.sh broker update $X --cpus ${BROKER_CPU} --heap ${BROKER_HEAP} --mem ${BROKER_MEM} --options log.dirs=${NFSLOC},delete.topic.enable=true
done

echo "Starting Brokers 1..${BROKER_COUNT}"
./kafka-mesos.sh broker start 1..${BROKER_COUNT}

echo ""
echo ""
echo "$APP_NAME, installed to ${APP_HOME}, has been started via Marathon"
echo "In addition, Brokers have been added and started per the settings provided"
echo ""
echo ""
rm $TFILE
