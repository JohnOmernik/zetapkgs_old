#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="drill"


APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"


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
        IMG=$(echo $IMG_LINE|cut -f1 -d" ")
        IMG_TAG=$(echo $IMG_LINE|grep -o -P "v\d.\d[^ ]+")
        CID=$(sudo docker run -d $IMG:$IMG_TAG /bin/bash)
        sudo docker cp $CID:/opt/mapr/lib/libjpam.so $APP_ROOT/libjpam
    fi
fi
echo "Building!"
cd ${APP_ROOT}


BUILD_TMP="./tmpbuilder"

APP_URL_ROOT="http://package.mapr.com/releases/ecosystem-5.x/redhat/"
APP_URL_FILE="mapr-drill-1.6.0.201606241408-1.noarch.rpm"

APP_URL="${APP_URL_ROOT}${APP_URL_FILE}"


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
    cp -R ${APP_ROOT}/libjpam ./
    cp -R ${APP_ROOT}/extrajars ./

cat > ./pkg_drill.sh << EOF
wget $APP_URL
rpm2cpio $APP_URL_FILE | cpio -idmv 
APP_VER=\$(ls ./opt/mapr/drill)
APP_TGZ="\${APP_VER}.tgz"
mv ./opt/mapr/drill/\${APP_VER} ./
cd \${APP_VER}
mv ./conf ./conf_orig
cp -R /app/libjpam ./
cp /app/extrajars/* ./jars/3rdparty/
cd ..
chown -R zetaadm:zetaadm \${APP_VER}
tar zcf \${APP_TGZ} \${APP_VER}
rm -rf ./opt
rm -rf \${APP_VER}
rm ${APP_URL_FILE}
EOF
chmod +x ./pkg_drill.sh

cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/buildbase
ADD extrajars /app/extrajars/
ADD libjpam /app/libjpam
ADD pkg_drill.sh ./
RUN ./pkg_drill.sh
CMD ["/bin/bash"]
EOL

    sudo docker build -t $TMP_IMG .
    CID=$(sudo docker run -d $TMP_IMG sleep 5)
    APP_TGZ1=$(sudo docker exec -it $CID ls -1|grep drill-)
    APP_VER=$(echo $APP_TGZ1|sed "s/\.tgz/@/"|cut -f1 -d"@")
    APP_TGZ="$APP_VER.tgz"
    sudo docker kill $CID
    sudo docker rm $CID
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
