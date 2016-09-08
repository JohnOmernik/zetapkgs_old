#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="mariadb"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh

CURUSER=$(whoami)


echo ""
echo "Starting $APP_NAME instance $APP_ID"
echo ""
echo ""
curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_HOME}/${APP_ID}.marathon -H "Content-type: application/json"
echo ""
echo ""
