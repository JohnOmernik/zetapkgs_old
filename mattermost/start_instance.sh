#!/bin/bash

CLUSTERNAME=$(ls /mapr)

APP_NAME="mattermost"

. /mapr/${CLUSTERNAME}/zeta/kstore/env/zeta_shared.sh
. /mapr/${CLUSTERNAME}/zeta/shared/preinst/general.inc.sh

CURUSER=$(whoami)

APP_MARATHON_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MARATHON_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MARATHON_WEB_FILE="${APP_HOME}/marathon_web.json"



echo ""
echo "Starting $APP_NAME instance $APP_ID"
echo ""
echo ""
echo "First Starting DB"
curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_DB_FILE} -H "Content-type: application/json"
echo ""
echo ""

read -e -p "This is a pause to ensure the DB is up"
echo ""
echo ""
echo "Now Starting App"
curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_APP_FILE} -H "Content-type: application/json"
echo ""
echo ""
read -e -p "This is a pause to ensure the APP is up"
echo ""
echo ""
echo "Now Starting WEB"
curl -X POST $ZETA_MARATHON_SUBMIT -d @${APP_MARATHON_WEB_FILE} -H "Content-type: application/json"
echo ""
echo ""
