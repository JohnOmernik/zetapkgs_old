#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="drill"

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


#APP_VER="drill-1.8.0"
#APP_TGZ="${APP_VER}.tgz"
#APP_URL_ROOT="http://package.mapr.com/releases/ecosystem-5.x/redhat/"
#APP_URL_FILE="mapr-drill-1.8.0.201609121517-1.noarch.rpm"



mkdir -p $APP_PKG_DIR
mkdir -p ${APP_ROOT}/extrajars
mkdir -p ${APP_ROOT}/libjpam
echo "Place to store custom jars" > ${APP_ROOT}/extrajars/jars.txt
JPAM=$(ls ${APP_ROOT}/libjpam)

if [ "$JPAM" == "" ]; then
    echo "No Lib JPAM found, should we grab one from a MapR container?"
    read -e -p "Pull libjpam.so from maprdocker? " -i "Y" PULLJPAM
    if [ "$PULLJPAM" == "Y" ]; then
        IMG_LINE=$(sudo docker images|grep "\/maprdocker")
        #IMG=$(echo $IMG_LINE|cut -f1 -d" ")
        IMG=$(echo $IMG_LINE|grep -o -P "maprdocker[^ ]+")
#        IMG_TAG=$(echo $IMG_LINE|grep -o -P "v\d.\d[^ ]+")
        CID=$(sudo docker run -d $IMG /bin/bash)
        sudo docker cp $CID:/opt/mapr/lib/libjpam.so $APP_ROOT/libjpam
    fi
fi
echo "Building!"
cd ${APP_ROOT}

if [ -f "$APP_PKG_DIR/$APP_TGZ" ]; then
    echo "The version you specified already exists. Do you wish to rebuild? (If not, this script will exit)"
    read -e -p "Rebuild $APP_VER? " -i "N" REBUILD
    if [ "$REBUILD" != "Y" ]; then
        echo "Not rebuilding and exiting"
        exit 1
    fi
fi



BUILD_TMP="./tmpbuilder"

#APP_URL_ROOT="http://package.mapr.com/releases/ecosystem-5.x/redhat/"
#APP_URL_FILE="mapr-drill-1.8.0.201609121517-1.noarch.rpm"

#APP_URL="${APP_URL_ROOT}${APP_URL_FILE}"

REQ_APP_IMG_NAME="maprbase buildbase"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

for IMG in $REQ_APP_IMG_NAME; do
    RQ_IMG_CHK=$(sudo docker images|grep "\/${IMG}")
    if [ "$RQ_IMG_CHK" == "" ]; then
        echo "This install requires the the image $IMG"
        echo "Please install this package before proceeding"
        exit 1
    fi
done

BUILD="Y"
TMP_IMG="zeta/drillbuild"
if [ "$BUILD" == "Y" ]; then
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > ./pkg_drill.sh << EOF
wget $APP_URL
rpm2cpio $APP_URL_FILE | cpio -idmv
echo "Moving ./opt/mapr/drill/${APP_VER} to ./"
mv ./opt/mapr/drill/${APP_VER} ./
echo "cd into ${APP_VER}"
cd ${APP_VER}
mv ./conf ./conf_orig
cd ..
chown -R zetaadm:zetaadm ${APP_VER}
tar zcf ${APP_TGZ} ${APP_VER}
rm -rf ./opt
rm -rf ${APP_VER}
rm ${APP_URL_FILE}
EOF
chmod +x ./pkg_drill.sh

cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/buildbase
ADD pkg_drill.sh ./
RUN ./pkg_drill.sh
CMD ["/bin/bash"]
EOL

    sudo docker build -t $TMP_IMG .
    sudo docker run --rm -v=`pwd`:/app/tmp $TMP_IMG cp $APP_TGZ /app/tmp/
    echo "App Fun: ${APP_TGZ}"
    sudo docker rmi -f $TMP_IMG

    if [ -f "$APP_PKG_DIR/$APP_TGZ" ]; then
        echo "The currently built TGZ ${APP_TGZ} already exists in $APP_PKG_DIR"
        echo "Do you wish to replace the existing one in the package directory with the recently built version?"
        read -e -p "Replace package? " -i "N" REPLACE_TGZ
    else
        REPLACE_TGZ="Y"
    fi

    if [ "$REPLACE_TGZ" == "Y" ]; then
        mv ${APP_TGZ} ${APP_PKG_DIR}/
    fi
    cd ..
else
    echo "Will not rebuild"
fi



sudo rm -rf $BUILD_TMP
echo ""
echo "$APP_NAME built"
echo "You can install instances with $APP_ROOT/install_instance.sh"
echo ""
