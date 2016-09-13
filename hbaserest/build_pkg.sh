#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="hbaserest"

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"

APP_PKG_DIR="${APP_ROOT}/packages"
APP_IMG_NAME="${ZETA_DOCKER_REG_URL}/hbaserestbase"

mkdir -p $APP_PKG_DIR


APP_URL_ROOT="http://package.mapr.com/releases/ecosystem-5.x/redhat/"
APP_URL_FILE="mapr-hbase-1.1.1.201602221251-1.noarch.rpm"

APP_URL="${APP_URL_ROOT}${APP_URL_FILE}"
BUILD_TMP="./tmpbuilder"

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

TMP_IMG="zeta/hbaserestbuild"
if [ "$BUILD" == "Y" ]; then
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > ./pkg_hbaserest.sh << EOF
wget $APP_URL
rpm2cpio $APP_URL_FILE | cpio -idmv 
APP_VER=\$(ls ./opt/mapr/hbase)
APP_TGZ="\${APP_VER}.tgz"
mv ./opt/mapr/hbase/\${APP_VER} ./
cd \${APP_VER}
mv ./conf ./conf_orig
cd ..
chown -R zetaadm:zetaadm \${APP_VER}
tar zcf \${APP_TGZ} \${APP_VER}
rm -rf ./opt
rm -rf \${APP_VER}
rm ${APP_URL_FILE}
EOF

chmod +x ./pkg_hbaserest.sh

cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/buildbase
ADD pkg_hbaserest.sh ./
RUN ./pkg_hbaserest.sh
CMD ["/bin/bash"]
EOL

    sudo docker build -t $TMP_IMG .
    CID=$(sudo docker run -d $TMP_IMG sleep 5)
    APP_TGZ1=$(sudo docker exec -it $CID ls -1|grep hbase-)
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
        sudo chown zetaadm:zetaadm ${APP_PKG_DIR}/${APP_TGZ}
    fi
    cd ..
    sudo rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi

sudo docker pull ${APP_IMG_NAME}
HCHECK=$(sudo docker images|grep ${APP_IMG_NAME})
if [ "$HCHECK" == "" ]; then
    rm -rf ./dockerbuild
    mkdir -p dockerbuild
    cd dockerbuild
    cp ${APP_PKG_DIR}/${APP_TGZ} ./

cat > ./Dockerfile << EOL1

FROM ${ZETA_DOCKER_REG_URL}/maprbase

ADD ${APP_TGZ} /

cmd ["java -version"]
EOL1
    sudo docker build -t $APP_IMG_NAME .
    sudo docker push $APP_IMG_NAME
    cd ..
    rm -rf ./dockerbuild
fi

echo ""
echo "$APP_NAME built"
echo "You can install instances with $APP_ROOT/install_instance.sh"
echo ""
