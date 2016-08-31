#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="maprbase"

APP_IMG_NAME="maprbase"

APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_IMG_NAME}"

BUILD_TMP="./tmpbuilder"

DOCKER_CHK=$(sudo docker ps)

if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi

IMG_CHK=$(sudo docker images|grep "\/${APP_IMG_NAME}")
if [ "$IMG_CHK" != "" ]; then
    echo "A $APP_IMG_NAME image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi

if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

    echo "This Docker file requires the cluster.conf file and the location of initial CREDs"

    echo "Please enter the location of the cluster.conf"
    read -e -p "Cluster.conf location: " -i "/home/zetaadm/maprdcos/cluster.conf" CLUSTER_CONF

    if [ ! -f "$CLUSTER_CONF" ]; then
        echo  "We can't proceed without a proper cluster.conf"
        exit 1
    else
        . $CLUSTER_CONF
    fi

    echo "Please enter the location of the credfile: "
    read -e -p "Credfile: " -i "/home/zetaadm/creds/creds.txt" CREDFILE

    if [ ! -f "$CREDFILE" ]; then
        echo "We need this for the docker containers"
        exit 1
    fi
    MAPR_CRED=$(cat $CREDFILE|grep "mapr\:")
    ZETA_CRED=$(cat $CREDFILE|grep "zetaadm\:")

    if [ "$DOCKER_PROXY" != "" ]; then
        DOCKER_LINE1="ENV http_proxy=$DOCKER_PROXY"
        DOCKER_LINE2="ENV HTTP_PROXY=$DOCKER_PROXY"
        DOCKER_LINE3="ENV https_proxy=$DOCKER_PROXY"
        DOCKER_LINE4="ENV HTTPS_PROXY=$DOCKER_PROXY"
    else
        DOCKER_LINE1=""
        DOCKER_LINE2=""
        DOCKER_LINE3=""
        DOCKER_LINE4=""
    fi



cat > ./Dockerfile << EOL
FROM ubuntu:latest

$DOCKER_LINE1
$DOCKER_LINE2
$DOCKER_LINE3
$DOCKER_LINE4

RUN adduser --disabled-login --gecos '' --uid=2500 zetaadm && adduser --disabled-login --gecos '' --uid=2000 mapr

RUN echo "$MAPR_CRED"|chpasswd &&  echo "$ZETA_CRED"|chpasswd

RUN usermod -a -G root mapr && usermod -a -G root zetaadm && usermod -a -G adm mapr && usermod -a -G adm zetaadm && usermod -a -G disk mapr && usermod -a -G disk zetaadm

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -qq -y libpam-ldap nscd openjdk-8-jre wget perl netcat syslinux-utils

RUN echo "Name: activate mkhomedir" > /usr/share/pam-configs/my_mkhomedir && echo "Default: yes" >> /usr/share/pam-configs/my_mkhomedir && echo "Priority: 900" >> /usr/share/pam-configs/my_mkhomedir && echo "Session-Type: Additional" >> /usr/share/pam-configs/my_mkhomedir && echo "Session:" >> /usr/share/pam-configs/my_mkhomedir && echo "      required               pam_mkhomedir.so umask=0022 skel=/etc/skel"

RUN echo "base $LDAP_BASE" > /etc/ldap.conf && echo "uri $LDAP_URL" >> /etc/ldap.conf && echo "binddn $LDAP_RO_USER" >> /etc/ldap.conf && echo "bindpw $LDAP_RO_PASS" >> /etc/ldap.conf && echo "ldap_version 3" >> /etc/ldap.conf && echo "pam_password md5" >> /etc/ldap.conf && echo "bind_policy soft" >> /etc/ldap.conf

RUN DEBIAN_FRONTEND=noninteractive pam-auth-update && sed -i "s/compat/compat ldap/g" /etc/nsswitch.conf && /etc/init.d/nscd restart

CMD ["/bin/bash"]

EOL


    sudo docker build -t $APP_IMG . 
    sudo docker push $APP_IMG
    cd ..
else
    echo "Will not rebuild"
fi
rm -rf $BUILD_TMP


echo ""
echo "$APP_IMG_NAME Image pushed to cluster shared docker and ready to role at $APP_IMG"
echo "No further action needed for this package as the base docker is available for other containers"
echo ""
