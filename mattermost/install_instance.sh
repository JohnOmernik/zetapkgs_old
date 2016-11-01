#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME=$(basename "$MYDIR")

APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}"

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh


echo "Application root is: $APP_ROOT"
echo "Application home is: $APP_HOME"

APP_IMG_DB="${ZETA_DOCKER_REG_URL}/${APP_NAME}_db"
APP_IMG_APP="${ZETA_DOCKER_REG_URL}/${APP_NAME}_app"
APP_IMG_WEB="${ZETA_DOCKER_REG_URL}/${APP_NAME}_web"


APP_MARATHON_DB_FILE="${APP_HOME}/marathon_db.json"
APP_MARATHON_APP_FILE="${APP_HOME}/marathon_app.json"
APP_MARATHON_WEB_FILE="${APP_HOME}/marathon_web.json"

mkdir -p $APP_HOME
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/


mkdir -p ${APP_HOME}/db_data
mkdir -p ${APP_HOME}/db_init
mkdir -p ${APP_HOME}/app_config
mkdir -p ${APP_HOME}/app_data
mkdir -p ${APP_HOME}/web_certs

echo ""
echo "Information related to DB Server:"
echo ""
read -e -p "Please enter the PostGres DB port to use use with mattermost: " -i "30480" APP_DB_PORT
echo ""
read -e -p "Please enter the amount of CPU to limit the Postgres instance for MM to: " -i "2.0" APP_DB_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the Postgres instance for MM to: " -i "8192" APP_DB_MEM
echo ""
read -e -p "Please enter a username for the DB user for Mattermost: " -i "mmuser" APP_DB_USER
echo ""

echo "Please enter the password for the DB User for Mattermost"
stty -echo
printf "Please enter new password for for the Mattermost DB User - ${APP_DB_USER}: "
read MM_PASS1
echo ""
printf "Please re-enter password for ${APP_DB_USER}: "
read MM_PASS2
echo ""
stty echo

# If the passwords don't match, keep asking for passwords until they do
while [ "$MM_PASS1" != "$MM_PASS2" ]
do
    echo "Passwords entered for ${APP_DB_USER} do not match, please try again"
    stty -echo
    printf "Please enter new password for ${APP_DB_USER} the Mattermost DB Users: "
    read MM_PASS1
    echo ""
    printf "Please re-enter password for ${APP_DB_USER}: "
    read MM_PASS2
    echo ""
    stty echo
done

APP_DB_PASS="$MM_PASS1"

echo "Information related to Application Server:"
echo ""
read -e -p "Please enter a port for the mattermost application server:: " -i "30481" APP_APP_PORT
echo ""
read -e -p "Please enter the amount of CPU to limit the MM app server: " -i "2.0" APP_APP_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the MM app server: " -i "2048" APP_APP_MEM
echo ""


echo "Information related to Web Server:"
echo ""
read -e -p "Please enter a http port to use with mattermost: " -i "30482" APP_HTTP_PORT
echo ""
read -e -p "Please enter a https port to use with mattermost: " -i "30483" APP_HTTPS_PORT
echo ""
read -e -p "Please enter the amount of CPU to limit the MM web server: " -i "2.0" APP_WEB_CPU
echo ""
read -e -p "Please enter the amount of Memory to limit the MM web server: " -i "2048" APP_WEB_MEM
echo ""
echo "Networking:"
echo ""
echo "You can user default networking or calico networking. "
read -e -p "Do you wish to use calico (Y for calico, N for default): " -i "N" APP_NET
if [ "$APP_NET" == "Y" ]; then
    echo "Calico needs more work here"
    APP_DOMAIN_ROOT="marathon.mesos"
else
    echo "Using default networking"
    APP_DOMAIN_ROOT="marathon.slave.mesos"
fi
echo ""
echo ""

echo "TODO: Use better password setup"

echo ""
echo ""

cat > ${APP_HOME}/db_init/run.sh << EOI
#!/bin/bash

export MM_USERNAME="$APP_DB_USER"
export MM_PASSWORD="$APP_DB_PASS"
echo "Starting Docker Entry Point"
/docker-entrypoint1.sh
EOI
chmod +x ${APP_HOME}/db_init/run.sh


cat > $APP_MARATHON_DB_FILE << EOD
{
  "id": "${APP_ROLE}/${APP_ID}/mattermostdb",
  "cmd": "/db_init/run.sh",
  "cpus": ${APP_DB_CPU},
  "mem": ${APP_DB_MEM},
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_DB}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 5432, "hostPort": ${APP_DB_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/db_init", "hostPath": "${APP_HOME}/db_init", "mode": "RO" },
      { "containerPath": "/var/lib/postgresql/data", "hostPath": "${APP_HOME}/db_data", "mode": "RW" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOD

cat > ${APP_HOME}/app_init/run.sh << EOQ
#!/bin/bash

export MM_USERNAME="$APP_DB_USER"
export MM_PASSWORD="$APP_DB_PASS"
echo "Starting Docker Entry Point"
/docker-entry.sh
EOQ

chmod +x ${APP_HOME}/app_init/run.sh

cat > $APP_MARATHON_APP_FILE << EOA
{
  "id": "${APP_ROLE}/${APP_ID}/mattermostapp",
  "cmd": "/mattermost/config/run.sh",
  "cpus": ${APP_APP_CPU},
  "mem": ${APP_APP_MEM},
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "DB_HOST": "mattermostdb-${APP_ID}-${APP_ROLE}.${APP_DOMAIN_ROOT}",
    "DB_PORT_5432_TCP_PORT": "${APP_DB_PORT}"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_APP}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 80, "hostPort": ${APP_APP_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/mattermost/config", "hostPath": "${APP_HOME}/app_config", "mode": "RW" },
      { "containerPath": "/mattermost/data", "hostPath": "${APP_HOME}/app_data", "mode": "RW" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOA

#Temp fix to specify application host in web container.

cat > ${APP_HOME}/web_certs/run.sh << EOR
#!/bin/bash
sed -i "s@http://app@http://${APP_HOST}@" /etc/nginx/sites-available/mattermost
sed -i "s@http://app@http://${APP_HOST}@" /etc/nginx/sites-available/mattermost-ssl
/docker-entry.sh
EOR
chmod +x ${APP_HOME}/web_certs/run.sh

cat > $APP_MARATHON_WEB_FILE << EOW
{
  "id": "${APP_ROLE}/${APP_ID}/mattermostweb",
  "cmd": "/cert/run.sh",
  "cpus": ${APP_WEB_CPU},
  "mem": ${APP_WEB_MEM},
  "instances": 1,
  "labels": {
   "CONTAINERIZER":"Docker"
  },
  "env": {
    "APP_HOST": "mattermostapp-${APP_ID}-${APP_ROLE}.${APP_DOMAIN_ROOT}",
    "PLATFORM_PORT_80_TCP_PORT": "${APP_APP_PORT}"
  },
  "ports": [],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${APP_IMG_WEB}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 80, "hostPort": ${APP_HTTP_PORT}, "servicePort": 0, "protocol": "tcp"},
        { "containerPort": 443, "hostPort": ${APP_HTTPS_PORT}, "servicePort": 0, "protocol": "tcp"}
      ]
    },
    "volumes": [
      { "containerPath": "/cert", "hostPath": "${APP_HOME}/web_certs", "mode": "RO" },
      { "containerPath": "/etc/localtime", "hostPath": "/etc/localtime", "mode": "RO" }
    ]

  }
}
EOW


echo ""
echo ""
echo "Instance created at ${APP_HOME}"
echo ""
echo "To start run ${APP_HOME}/start_instance.sh"
echo ""
echo ""




