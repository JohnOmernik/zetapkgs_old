#!/bin/bash


echo "Instance install of $APP_PKG requested on $CLUSTERNAME"
echo ""
read -e -p "Which role do you wish to install $APP_PKG into on $CLUSTERNAME? " APP_ROLE

echo ""
echo "The recommended install location for $APP_PKG is $REC_DIR"
read -e -p "Which install location do you wish to use for $APP_PKG? " -i $REC_DIR APP_DIR

if [ ! -d "/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE" ]; then
    echo "The role $APP_ROLE doesn't appear to be installed."
    exit 1
fi

echo ""
read -e -p "What is the id you wish to use for the instance of $APP_PKG? " APP_ID
echo ""

APP_ROOT="/mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE/$APP_PKG/$APP_ID"

if [ -d "$APP_ROOT" ]; then
    echo "There is an install of $APP_PKG that already exists at $APP_ROOT with that ID"
    echo "exiting"
    exit 1
fi

