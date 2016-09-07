#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="zeppelin"


APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/${APP_NAME}"
APP_PKG_DIR="${APP_ROOT}/packages"


mkdir -p $APP_PKG_DIR

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


echo "To make your $APP package more complete, please specify a drill TGZ to include the JDBC jar for"
echo ""

DRILL_ROOT="/mapr/${CLUSTERNAME}/zeta/shared/drill"
DRILL_PKG_DIR="$DRILL_ROOT/packages"

ls -ls ${DRILL_PKG_DIR}
echo ""
read -e -p "Please enter the drill package to use for JDBC Drivers: " -i "drill-1.6.0.tgz" DRILL_TGZ
DRILL_VER=$(echo -n ${DRILL_TGZ}|sed "s/\.tgz//")

rm -rf ${BUILD_TMP}
mkdir -p ${BUILD_TMP}
cd ${BUILD_TMP}


BUILD="Y"

PCHECK=$(sudo docker images|grep zep_build)
OCHECK=$(sudo docker images|grep zep_run)

if [ "$PCHECK" == "" ] || [ "$OCHECK" == "" ]; then
    echo "Building images because one of the two does not exist"
else
    read -e -p "Looks like the build and run images for Zeppelin already exist. Do you want to rebuild? " -i "N" BUILD
fi

APP_BUILD_IMG="${ZETA_DOCKER_REG_URL}/zep_build"
APP_RUN_IMG="${ZETA_DOCKER_REG_URL}/zep_run"

mkdir -p ./zep_build
mkdir -p ./zep_run


if [ "$ZETA_DOCKER_PROXY" != "" ]; then
    P_HOST=$(echo $ZETA_DOCKER_PROXY|cut -f2 -d":"|sed "s@//@@")
    P_PORT=$(echo $ZETA_DOCKER_PROXY|cut -f3 -d":")
    echo "Proxy Host: $P_HOST"
    echo "Proxy Port: $P_PORT"
    NPM_PROXY="RUN npm config set proxy $ZETA_DOCKER_PROXY && npm config set https-proxy $ZETA_DOCKER_PROXY && mkdir -p /root/.m2"
    MVN_PROXY="ADD settings.xml /root/.m2/"
cat > ./zep_build/settings.xml << EO9
<settings>
<proxies>
<proxy>
<id>http-1</id>
<active>true</active>
<protocol>http</protocol>
<host>$P_HOST</host>
<port>$P_PORT</port>
</proxy>
<proxy>
<id>https-1</id>
<active>true</active>
<protocol>https</protocol>
<host>$P_HOST</host>
<port>$P_PORT</port>
</proxy>
</proxies>
</settings>
EO9
else
    NPM_PROXY=""
fi

cat > ./zep_build/Dockerfile << EOF
FROM ${ZETA_DOCKER_REG_URL}/buildbase
RUN apt-get update && apt-get install -y openjdk-8-jdk git npm libfontconfig wget
$NPM_PROXY
$MVN_PROXY
RUN wget http://apache.cs.utah.edu/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz && tar -zxf apache-maven-3.3.9-bin.tar.gz -C /usr/local/ && ln -s /usr/local/apache-maven-3.3.9/bin/mvn /usr/local/bin/mvn && rm apache-maven-3.3.9-bin.tar.gz && mkdir -p /app
WORKDIR /app
EOF

cat > ./zep_run/Dockerfile << EOF1
FROM ${ZETA_DOCKER_REG_URL}/maprbase
RUN apt-get install -y python python-dev build-essential python-boto libcurl4-nss-dev libsasl2-dev libsasl2-modules maven libapr1-dev libsvn-dev
CMD ["python -V"]

EOF1

if [ "$BUILD" == "Y" ]; then
    cd zep_build
    sudo docker build -t $APP_BUILD_IMG .
    cd ..
    cd zep_run
    sudo docker build -t $APP_RUN_IMG .
    sudo docker push ${APP_RUN_IMG}
    cd ..
fi


##############
#Provide example GIT Settings
APP_GIT_URL="https://github.com"
APP_GIT_USER="apache"
APP_GIT_REPO="incubator-zeppelin"
git clone ${APP_GIT_URL}/${APP_GIT_USER}/${APP_GIT_REPO}


echo "Create a mini build script"

if [ "$ZETA_DOCKER_PROXY" != "" ]; then
cat > ./${APP_GIT_REPO}/build.sh << EOF8
#!/bin/bash
export MAVEN_OPTS="-Xmx2g -XX:MaxPermSize=1024m -Dhttp.proxyHost=$P_HOST -Dhttp.proxyPort=$P_PORT -Dhttps.proxyHost=$P_HOST -Dhttps.proxyPort=$P_PORT"
mvn clean package -DskipTests
EOF8
else

cat > ./${APP_GIT_REPO}/build.sh << EOF2
#!/bin/bash
export MAVEN_OPTS="-Xmx2g -XX:MaxPermSize=1024m"
mvn clean package -DskipTests
EOF2
fi

chmod +x ./${APP_GIT_REPO}/build.sh

echo "Use the build image to build Zeppelin"

sudo docker run -t --rm -v=`pwd`/${APP_GIT_REPO}:/app ${APP_BUILD_IMG} /app/build.sh



echo "Getting Current version from pom.xml"
cd ${APP_GIT_REPO}
APP_VER=$(grep -m1 "<version>" pom.xml | cut -d">" -f2 | cut -d"<" -f1)
cd ..

echo "Pulling Drill JDBC Files"
cp ${DRILL_PKG_DIR}/${DRILL_TGZ} ./
tar zxf ${DRILL_TGZ}
sudo cp ./${DRILL_VER}/jars/jdbc-driver/drill-jdbc-all* ./${APP_GIT_REPO}/interpreter/jdbc/
rm -rf ./${DRILL_VER}


echo "Packaging Zeppelin"
sudo mv ${APP_GIT_REPO} "${APP_NAME}-${APP_VER}"
APP_TGZ="${APP_NAME}-${APP_VER}.tgz"
sudo chown -R zetaadm:zetaadm "${APP_NAME}-${APP_VER}"
tar zcf ${APP_TGZ} ${APP_NAME}-${APP_VER}/

##############
# Finanlize location of pacakge

# Tag and upload docker image if needed locally if needed (zeta is for local, but consider using the env variables for the roles)


if [ -f "${APP_PKG_DIR}/${APP_TGZ}" ]; then
    echo "This package already exists. We can exit now, without overwriting, or you can overwrite with the package you just built"
    read -e -p "Should we overwrite ${APP_TGZ} located in ${APP_PKG_DIR} with the currently built package? (Y/N): " -i "N" OW
    if [ "$OW" == "Y" ]; then
        mv ${APP_TGZ} ${APP_PKG_DIR}/
    else
        echo "Not moving recently built package"
    fi
else
    mv ${APP_TGZ} ${APP_PKG_DIR}/
fi



cd ..
rm -rf ${BUILD_TMP}

##############
# Provide next step instuctions
echo ""
echo ""
echo "${APP_NAME} release is prepped for use and uploaded to docker registry or copied to ${APP_PKG_DIR}"
echo ""
echo "Then, next step is to install a running instace of ${APP_NAME}"
echo ""
echo "> ${APP_ROOT}/install_instance.sh"
echo ""
echo ""
