# General Include

re="^[a-z0-9]+$"
if [[ ! "${APP_NAME}" =~ $re ]]; then
    echo "App name can only be lowercase letters and numbers"
    exit 1
fi

#### Create upper case APP for use in ENV variables
APP_UP=$(echo $APP_NAME | tr '[:lower:]' '[:upper:]')

###############
# Get APP_DIR
# We guess this... should we assume we'll always guess right? I think it's safe but perhaps we should validate

APP_DIR_GUESS=$(echo "$(realpath "$0")"|cut -d"/" -f4)
APP_DIR="${APP_DIR_GUESS}"
echo ""
echo "Using autodetected APP_DIR: ${APP_DIR}"
echo ""

###############
# Get APP_ROLE
# The code to ask for this was removed. The idea is this code should only be called from the right directory, therefore we know the roll.

APP_ROLE_GUESS=$(echo "$(realpath "$0")"|cut -d"/" -f5)
APP_ROLE="${APP_ROLE_GUESS}"
echo ""
echo "Using autodetected APP_ROLE: ${APP_ROLE}"
echo ""


##############
# GET APP_ID
# If the APP_ID is set by the calling script, we don't need need to ask. Some frameworks demand a certain role setup and will only install there
#

APP_ID_GUESS=$(basename $(dirname `realpath "$0"`))
read -e -p "We autodetected the instance to be ${APP_ID_GUESS}. Please enter/confirm the instance name: " -i ${APP_ID_GUESS} APP_ID

if [[ ! "${APP_ID}" =~ $re ]]; then
    echo "App instance name can only be lowercase letters and numbers"
    exit 1
fi

APP_ROOT="/mapr/${CLUSTERNAME}/zeta/shared/${APP_NAME}"
APP_HOME="/mapr/${CLUSTERNAME}/${APP_DIR}/${APP_ROLE}/${APP_NAME}/${APP_ID}"
APP_PKG_DIR="${APP_ROOT}/packages"


