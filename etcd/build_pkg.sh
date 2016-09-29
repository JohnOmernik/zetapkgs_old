#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh


APP_NAME="etcd"
APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"

mkdir -p $APP_ROOT

BUILD_TMP="./tmpbuilder"
APP_IMG_NAME="${APP_NAME}"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_IMG_NAME}"

REQ_APP_IMG_NAME="maprbase"

DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

RQ_IMG_CHK=$(sudo docker images|grep "\/${REQ_APP_IMAGE_NAME}")
if [ "$RQ_IMG_CHK" == "" ]; then
    echo "This install requires the the image $REQ_APP_IMG_NAME"
    echo "Please install this package before proceeding"
    exit 1
fi


IMG_CHK=$(sudo docker images|grep "\/${APP_IMG_NAME}")
if [ "$IMG_CHK" != "" ]; then
    echo "A ${APP_IMG_NAME} image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi
GO_BUILD_CHK=$(sudo docker images|grep gobuildbase)
if [ "$GO_BUILD_CHK" == "" ]; then
    echo "Need to build gobuildbase"
    BUILD_CHK=$(sudo docker images|grep buildbase)
    if [ "$BUILD_CHK" == "" ]; then
        echo "Need to have the buildbase image installed"
        exit 1
    fi
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    GO_URL_BASE="https://storage.googleapis.com/golang/"
    GO_URL_FILE="go1.6.linux-amd64.tar.gz"
    GO_URL="${GO_URL_BASE}${GO_URL_FILE}"

cat > ./Dockerfile << EOL
FROM ${ZETA_DOCKER_REG_URL}/buildbase
RUN apt-get update && apt-get install -y build-essential git
RUN curl -O $GO_URL && tar xvf $GO_URL_FILE &&  chown -R root:root ./go && mv go /usr/local
RUN echo "export GOPATH=\$HOME/work" >> /root/.profile
RUN echo "export PATH=\$PATH:/usr/local/go/bin:\$GOPATH/bin" >> /root/.profile
RUN . /root/.profile
CMD ["/bin/bash"]
EOL
    sudo docker build -t ${ZETA_DOCKER_REG_URL}/gobuildbase .
    cd ..
fi


APP_URL_BASE="https://github.com/mesosphere/"
APP_URL_FILE="etcd-mesos"

APP_URL="${APP_URL_BASE}${APP_URL_FILE}"

if [ "$BUILD" == "Y" ]; then
    sudo rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP
    CUR_DIR=$(pwd)
    git clone $APP_URL
cat > ./build.sh << EOL2
#!/bin/bash
. /root/.profile
cd /app/${APP_URL_FILE}
sed -i "s*git@*https://*" .gitmodules
sed -i "s*git@*https://*" .git/config

sed -i "s*com:coreos*com/coreos*" .gitmodules
sed -i "s*com:coreos*com/coreos*" .git/config
make
EOL2
    chmod +x build.sh
    sudo docker run --rm -v=${CUR_DIR}:/app:rw ${ZETA_DOCKER_REG_URL}/gobuildbase /app/build.sh

    cd $APP_URL_FILE
    sed -i "s@FROM debian@FROM ${ZETA_DOCKER_REG_URL}/maprbase@" ./Dockerfile
    sudo docker build -t $APP_IMG .
    sudo docker push $APP_IMG
    cd ..
    cd ..
else
    echo "Will not rebuild"
fi

sudo rm -rf $BUILD_TMP

echo ""
echo "${APP_IMG_NAME} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo "No instance installs needed for this package"
echo ""
