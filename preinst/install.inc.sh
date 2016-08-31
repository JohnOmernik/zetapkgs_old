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

echo ""
read -e -p "What is the id you wish to use for the instance of $APP_NAME? " APP_ID
echo ""

APP_ROOT="/mapr/${CLUSTERNAME}/zeta/shared/${APP_NAME}"
APP_HOME="/mapr/${CLUSTERNAME}/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}"
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


