#!/bin/bash

CLUSTERNAME=$(ls /mapr)
APP_NAME="calico"
. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_DIR="zeta"
APP_ROLE="shared"
APP_ID="zetacalico"
APP_HOME="/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE/$APP_NAME/$APP_ID"

APP_PROX_MAR="${APP_HOME}/marathon_templates/etcd_proxy.template"
APP_NODE_MAR="${APP_HOME}/marathon_templates/node.template"
APP_NETLIB_MAR="${APP_HOME}/marathon_templates/netlib.template"

MARATHON_HOST="marathon.mesos"
MARATHON_PORT="8080"
MARATHON_URL="http://${MARATHON_HOST}:${MARATHON_PORT}"

STATUS_ONLY=$1

MGROUPS="/v2/groups"
MAPPS="/v2/apps"

MASTER="http://leader.mesos:5050/api/v1"

HOSTS=$(curl -s -H "Content-type: application/json" -X POST -d '{"type":"GET_AGENTS"}' ${MASTER}/GetAgents|grep -P -o "hostname\":\"[^\"]+\"")
AGENTS=""

for HOST in $HOSTS; do
    A=$(echo $HOST|cut -d":" -f2|sed "s/\"//g")
    AGENTS="$AGENTS $A "
done



for AGENT in $AGENTS; do
    AGENTID=$(echo $AGENT|sed "s/\./-/g")
    CHK_DOCKER=$(ssh -o StrictHostKeyChecking=no $AGENT sudo cat /etc/docker/daemon.json|grep localhost)
    if [ "$CHK_DOCKER" == "" ]; then
        DCK_STATUS="FAIL"
    else
        DCK_STATUS="OK"
    fi

    N="/${APP_ROLE}/${APP_ID}/nodes/node-${AGENTID}"
    #echo $C

    CHK=$(curl -s -H "Content-type: application/json" -X GET ${MARATHON_URL}${MAPPS}${N} | grep -P -o "\"instances\"\:\d{1,}"|cut -d":" -f2)

    if [ "$CHK" == "" ]; then
        NODE_STATUS="Not Installed"
    elif [ "$CHK" == "0" ]; then
        NODE_STATUS="Installed - Stopped"
    elif [ "$CHK" == "1" ]; then
        NODE_STATUS="Installed - Running"
    fi

    P="/${APP_ROLE}/${APP_ID}/etcdproxies/prox-${AGENTID}"
    #echo $C

    CHK=$(curl -s -H "Content-type: application/json" -X GET ${MARATHON_URL}${MAPPS}${P} | grep -P -o "\"instances\"\:\d{1,}"|cut -d":" -f2)

    if [ "$CHK" == "" ]; then
        PROX_STATUS="Not Installed"
    elif [ "$CHK" == "0" ]; then
        PROX_STATUS="Installed - Stopped"
    elif [ "$CHK" == "1" ]; then
        PROX_STATUS="Installed - Running"
    fi
    L="/${APP_ROLE}/${APP_ID}/netlibs/netlib-${AGENTID}"
    #echo $C

    CHK=$(curl -s -H "Content-type: application/json" -X GET ${MARATHON_URL}${MAPPS}${L} | grep -P -o "\"instances\"\:\d{1,}"|cut -d":" -f2)

    if [ "$CHK" == "" ]; then
        NET_STATUS="Not Installed"
    elif [ "$CHK" == "0" ]; then
        NET_STATUS="Installed - Stopped"
    elif [ "$CHK" == "1" ]; then
        NET_STATUS="Installed - Running"
    fi
    echo ""
    echo "##########################################"
    echo "Agent: $AGENT"
    echo ""
    echo "Docker Agent Status: $DCK_STATUS"
    echo "Calico Node Status: $NODE_STATUS"
    echo "Libnet Status: $NET_STATUS"
    echo "Etcd Proxy Status: $PROX_STATUS"
    echo ""

    if [ "$STATUS_ONLY" != "1" ]; then
        echo "Options: "
        echo "I - Install and Start Marathon Services for Calico on this node"
        echo "B - Begin (start) Marathon Services for Calico on this node"
        echo "E - End (stop)  Marathon Services for Calico on this node"
        echo "N - Skip Action on this node (go to next)"
        echo "Q - Quit now"
        echo ""
        read -e -p "Option: " OPTION


        if [ "$OPTION" == "I" ]; then
            cd $APP_HOME
            PROX_MAR="./proxies/prox_$AGENT.json"
            NODE_MAR="./nodes/node_$AGENT.json"
            NETLIB_MAR="./netlibs/netlib_$AGENT.json"

            mkdir -p ./nodes
            mkdir -p ./netlibs
            mkdir -p ./proxies

            sed "s/%HOST%/$AGENT/g" $APP_PROX_MAR | sed "s/%HOSTID%/$AGENTID/g" > $PROX_MAR
            sed "s/%HOST%/$AGENT/g" $APP_NODE_MAR | sed "s/%HOSTID%/$AGENTID/g" > $NODE_MAR
            sed "s/%HOST%/$AGENT/g" $APP_NETLIB_MAR | sed "s/%HOSTID%/$AGENTID/g" > $NETLIB_MAR

            echo "Starting Etcd Proxy on $AGENT"
            curl -s -H "Content-type: application/json" -X POST ${MARATHON_URL}${MAPPS} -d @${PROX_MAR}
            echo ""
            echo "Starting Calico Node on $AGENT"
            curl -s -H "Content-type: application/json" -X POST ${MARATHON_URL}${MAPPS} -d @${NODE_MAR}
            echo ""
            echo "Starting libnet on $AGENT"
            curl -s -H "Content-type: application/json" -X POST ${MARATHON_URL}${MAPPS} -d @${NETLIB_MAR}
            echo ""
        elif [ "$OPTION" == "E" ]; then
            echo "Stopping Etcd Proxy on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${P} -d'{"instances":0}'
            echo ""
            echo "Stopping Calico Node on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${N} -d'{"instances":0}'
            echo ""
            echo "Stopping Calico libnetwork on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${L} -d'{"instances":0}'
            echo ""
       elif [ "$OPTION" == "B" ]; then
            echo "Starting Etcd Proxy on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${P} -d'{"instances":1}'
            echo ""
            echo "Starting Calico Node on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${N} -d'{"instances":1}'
            echo ""
            echo "Starting Calico libnetwork on $AGENT"
            curl -s -H "Content-type: application/json" -X PUT ${MARATHON_URL}${MAPPS}${L} -d'{"instances":1}'
            echo ""
       elif [ "$OPTION" == "N" ]; then
            echo "Going to next host"
        elif [ "$OPTION" == "Q" ]; then
            echo "Exiting Now"
            exit 0
        else
            echo "Not Implemented yet"
        fi
    fi
done
