#!/bin/bash
CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_LIST_ALL="1"
REC_DIR="zeta"
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


APP_IMG="${ZETA_DOCKER_REG_URL}/usershell"
echo ""
echo ""
echo "This install instance of usershell, only creates the base directories.  The start instance actually creates the marathon file for each user that may be running a user shell."
echo ""


###############
# $APP Specific
echo "Resources"
read -e -p "Please enter the amount of Memory per Usershell: " -i "1024" APP_MEM
read -e -p "Please enter the amount of CPU shares to limit Usershell: " -i "1.0" APP_CPU
echo ""


##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
cd ${APP_HOME}


mkdir -p ${APP_HOME}
mkdir -p ${APP_HOME}/marathon
cp ${APP_ROOT}/profile_template ${APP_HOME}/
cp ${APP_ROOT}/nanorc_template ${APP_HOME}/
cp ${APP_ROOT}/bashrc_template ${APP_HOME}/
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/

chmod +x ${APP_HOME}/start_instance.sh

cat > $APP_HOME/instance_include.sh << EOL1
#!/bin/bash
APP_MEM="$APP_MEM"
APP_CPU="$APP_CPU"
APP_IMG="$APP_IMG"
EOL1



##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "> ${APP_HOME}/start_instance.sh"
echo ""

