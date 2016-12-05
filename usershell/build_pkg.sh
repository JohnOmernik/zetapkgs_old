#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_ROOT="/mapr/$CLUSTERNAME/zeta/shared/usershell"

mkdir -p $APP_ROOT

BUILD_TMP="./tmpbuilder"
APP_IMG_NAME="usershell"
APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_IMG_NAME}"

REQ_APP_IMG_NAME="buildbase"

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



if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > ./Dockerfile << EOL

FROM ${ZETA_DOCKER_REG_URL}/${REQ_APP_IMG_NAME}

WORKDIR /

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y pwgen openssh-server python libnss3 python-numpy python-dev python-pip git curl && apt-get clean && apt-get autoremove -y

RUN pip install xxhash && pip install lz4tools && pip install kafka-python && pip install requests

RUN mkdir /var/run/sshd

RUN echo "root:\$(pwgen -s 16 1)" | chpasswd

#RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

RUN echo "export LESSOPEN=\"| /usr/bin/lesspipe %s\"" >> /etc/profile
RUN echo "export LESSCLOSE=\"/usr/bin/lesspipe %s %s\"" >> /etc/profile
RUN echo "export LS_COLORS=\"rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:\"" >> /etc/profile

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
echo "${APP_IMG_NAME} Image pushed to cluster shared docker and ready to use at $APP_IMG"
echo "No instance installs needed for this package"
echo ""
