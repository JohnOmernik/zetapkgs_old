#!/bin/bash

echo ""
echo "Instance install of $APP_NAME requested on $CLUSTERNAME"
echo ""
read -e -p "Which role do you wish to install $APP_NAME into on $CLUSTERNAME? " APP_ROLE

echo ""
echo "The recommended install location for $APP_NAME is $REC_DIR"
echo ""
read -e -p "Which install location do you wish to use for $APP_NAME? " -i $REC_DIR APP_DIR

if [ ! -d "/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE" ]; then
    echo "The role $APP_ROLE doesn't appear to be installed."
    exit 1
fi
APP_USE_NAME="Y"
echo ""
read -e -p "What is the id you wish to use for the instance of $APP_NAME? " APP_ID

APP_HOME="/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE/$APP_NAME/$APP_ID"

echo ""
echo "Based on your selections, the install location will be '$APP_NAME/$APP_ID' under '$APP_DIR/$APP_ROLE'"
echo "i.e."
echo "$APP_HOME"
echo ""
echo "If you wish to nest your app in an application group, both in the directory structure and in marathon, you have that options now:"
echo ""
echo "For example, if you have a mariadb server you are installing with an APP_ID of myappmariadb, in the prod role installed to the zeta directory, the default location would be:"
echo ""
echo "/mapr/$CLUSTERNAME/zeta/prod/mariadb/myappmariadb"
echo ""
echo "And the Marathon ID would be prod/myappmariadb"
echo ""
echo "However, in this case you want the Maria DB APP to be nested under and application named myapp in prod, under the apps directory:"
echo ""
echo "/mapr/$CLUSTERNAME/apps/prod/myapp/myappmariadb"
echo ""
echo "Marathon location: prod/myaapp/myappmaridb"
echo ""
echo "You can do this by specifying and id that includes the nesting, and asking to NOT include App name in the install location"
echo "For Example"
echo ""
echo "APP_ID: myapp/myappmariadb"
echo "Use Applicaiton Name: False" 
echo ""
echo "Do you wish renter the APP_ID at this time? The Current Selections are:"
echo ""
echo "APP_ID: $APP_ID"
echo "APP_USE_NAME: $APP_USE_NAME"
echo "APP_HOME: $APP_HOME"
echo "Marathon ID: $APP_ROLE/$APP_ID"
echo ""
read -e -p  "Press Y to accept these defaults, or press N to renter the APP_ID: " -i "Y" REENTER

if [ "$REENTER" == "N" ]; then
    read -e -p "Use APP_NAME in the storage directory? " -i "Y" APP_USE_NAME
    echo ""
    read -e -p "New APP_ID to use: " -i "$APP_ID" APP_ID
    APP_HOME="/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE/$APP_ID"
    echo ""
    echo "The newly entered information is:"
    echo ""
    echo "APP_ID: $APP_ID"
    echo "APP_USE_NAME: $APP_USE_NAME"
    echo "APP_HOME: $APP_HOME"
    echo "Marathon ID: $APP_ROLE/$APP_ID"

    read -e -p "Does this look correct? " -i "Y" CORRECT
    if [ "$CORRECT" != "Y" ]; then
        echo ""
        echo "Information not correct, exiting"
        exit 1
    fi

elif [ "$REENTER" == "Y" ]; then
    echo "Using Entered Information"
else
    echo "No answer was given, exiting"
    exit 1
fi

APP_MARATHON_FILE="$APP_HOME/marathon.json"


APP_ROOT="/mapr/${CLUSTERNAME}/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"

if [ "$APP_LIST_ALL" == "1" ]; then
    echo "Application Name - APP_NAME: $APP_NAME"
    echo "Application Dir  - APP_DIR: $APP_DIR"
    echo "Application Role - APP_ROLE: $APP_ROLE"
    echo "Application ID   - APP_ID: $APP_ID"
    echo "Application Root - APP_ROOT: $APP_ROOT"
    echo "Application Home - APP_HOME: $APP_HOME"
    echo "App Package Dir  - APP_PKG_DIR: $APP_PKG_DIR"
fi


if [ -d "$APP_HOME" ]; then
    echo "There is an install of $APP_NAME that already exists at $APP_HOME with that ID"
    echo "exiting"
    exit 1
else
    mkdir -p $APP_HOME
fi


