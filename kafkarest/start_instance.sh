#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="kafkarest"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh

CURUSER=$(whoami)
APP_MARATHON_FILE="$APP_HOME/marathon.json"

echo ""
echo "Starting $APP_NAME instance $APP_ID"
echo ""
echo ""
curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_FILE} -H "Content-type: application/json"
echo ""
echo ""
