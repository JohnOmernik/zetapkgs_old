#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="marathon"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"

APP_PKG_DIR="${APP_ROOT}/packages"

APP_VER_FILE=$1
if [ "$APP_VER_FILE" == "" ]; then
    echo "You must specify which version of drill you wish to build by passing the appropriate .vers file to this script"
    echo "Current options are:"
    echo ""
    ls *.vers
    exit 1
fi

if [ ! -f "$APP_VER_FILE" ]; then
    echo "The provided vers file $APP_VER_FILE does not appear to exist.  Please choose from these options:"
    echo ""
    ls *.vers
    exit 1
fi
. $APP_VER_FILE


#APP_VER="marathon-1.3.5"
#APP_TGZ="${APP_VER}.tgz"

#APP_URL_ROOT="http://downloads.mesosphere.com/marathon/v1.3.5/"
#APP_URL_FILE="marathon-1.3.5.tgz"

#APP_URL="${APP_URL_ROOT}${APP_URL_FILE}"



mkdir -p $APP_PKG_DIR

if [ -f "$APP_PKG_DIR/$APP_TGZ" ]; then
    echo "The version you specified already exists. Do you wish to rebuild? (If not, this script will exit)"
    read -e -p "Rebuild $APP_VER? " -i "N" REBUILD
    if [ "$REBUILD" != "Y" ]; then
        echo "Not rebuilding and exiting"
        exit 1
    fi
fi

BUILD_TMP="./tmpbuilder"
sudo rm -rf $BUILD_TMP
mkdir -p $BUILD_TMP
cd $BUILD_TMP
echo ""
echo "Downloading Marathon $APP_VER"
wget $APP_URL
mv $APP_TGZ $APP_PKG_DIR/
echo ""
echo "Downloading Marathon LDAP $APP_LDAP_VER"
wget $APP_LDAP_URL
mv $APP_LDAP_URL_FILE $APP_PKG_DIR/$APP_LDAP_VER.jar
echo ""
cd ..
sudo rm -rf $BUILD_TMP

echo ""
echo "$APP_NAME package $APP_VER Build"
echo "You can install instances with $APP_ROOT/install_instance.sh"
echo ""
