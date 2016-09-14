#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="zeppelin"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh

CURUSER=$(whoami)

if [ "$CURUSER" != "$ZETA_IUSER" ]; then
    echo "Must use $ZETA_IUSER: User: $CURUSER"
fi

APP_MARATHON_FILE="$APP_HOME/marathon.json"
echo ""
echo "Submitting ${APP_ID} to Marathon then pausing 20 seconds to wait for start and API usability"
echo ""

curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_FILE} -H "Content-type: application/json"
echo ""
echo ""

