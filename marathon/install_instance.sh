#!/bin/bash
CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_LIST_ALL="1"

REC_DIR="zeta"

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

APP_NAME=$(basename "$MYDIR")

. /mapr/$CLUSTERNAME/zeta/shared/preinst/install.inc.sh

echo ""
echo "List of current packages of $APP_NAME:"
echo ""
ls -ls $APP_PKG_DIR
echo ""


read -e -p "Which version of $APP_NAME do you want to use? " -i "marathon-1.3.5.tgz" APP_BASE_FILE
echo ""
read -e -p "Which version of $APP_NAME LDAP do you want to use? " -i "marathon-ldap-1.3.jar" APP_LDAP_BASE_FILE
echo ""
APP_BASE="${APP_PKG_DIR}/$APP_BASE_FILE"
APP_LDAP_BASE="${APP_PKG_DIR}/${APP_LDAP_BASE_FILE}"

if [ ! -f "$APP_BASE" ]; then
    echo "$APP_NAME Version specified doesn't exist, please download and try again"
    echo "$APP_BASE"
    exit 1
fi

if [ ! -f "$APP_LDAP_BASE" ]; then
    echo "$APP_NAME LDAP Version specified doesn't exist, please download and try again"
    echo "$APP_LDAP_BASE"
    exit 1
fi

APP_VER=$(echo -n $APP_BASE_FILE|sed "s/\.tgz//")
APP_VER_NUM=$(echo $APP_VER|cut -d"-" -f2)

###############
# $APP Specific
echo "The next step will walk through instance defaults for ${APP_ID}"
echo ""
echo "Ports: "
read -e -p "Please enter the port for the Marathon API used for ${APP_ID}: " -i "28080" APP_PORT
echo ""
echo "Resources"
read -e -p "Please enter the amount of memory (total) for the $APP_ID instance of Marathon: " -i "2048" APP_MEM
read -e -p "Please enter the amount of CPU shares to limit the $APP_ID instance of Marathon: " -i "1.0" APP_CPU
echo ""
echo "Marathon can accept resources for $APP_ROLE only, or for * AND $APP_ROLE resources"
read -e -p "Should this instance of Marathon accept * resources as well as $APP_ROLE? " -i "N" APP_ROLE_ACCEPT
if [ "$APP_ROLE_ACCEPT" == "Y" ]; then
    APP_RESOURCES="$APP_ROLE,*"
else
    APP_RESOURCES="$APP_ROLE"
fi
echo ""

JAVA_HEAD=256

(( APP_JAVA_MEM = APP_MEM - JAVA_HEAD ))

##########
# Do instance specific things: Create Dirs, copy start files, make executable etc
mkdir -p ${APP_HOME}
cd ${APP_HOME}
APP_CERT_LOC="${APP_HOME}/certs"
mkdir -p ${APP_HOME}/logs
mkdir -p ${APP_HOME}/conf
mkdir -p ${APP_CERT_LOC}
cp ${APP_ROOT}/start_instance.sh ${APP_HOME}/

sudo chown -R zetaadm:zeta${APP_ROLE}zeta $APP_HOME/logs
sudo chmod 755 ${APP_HOME}/logs

sudo chown -R zetaadm:zeta${APP_ROLE}zeta $APP_HOME/conf
sudo chmod 770 ${APP_HOME}/conf

sudo chown -R zetaadm:zeta${APP_ROLE}zeta ${APP_CERT_LOC}
sudo chmod -R 750 ${APP_CERT_LOC}

CN_GUESS="${APP_ID}-${APP_ROLE}.marathon.slave.mesos"

# Doing Java Certs for marathon
. /mapr/$CLUSTERNAME/zeta/shared/zetaca/gen_java_keystore.sh


echo ""
echo "Updating Role ENV with this marathon"
echo ""
echo "Each role can have a marathon instance to use as the role's main marathon instance. Do you want to update your role ENV to use $APP_ID instance of marathon as the default?"
read -e -p  "Use $APP_ID for default $APP_ROLE Marathon? " -i "N" DEF_MAR
if [ "$DEF_MAR" == "Y" ]; then
    echo "Updating ENV File for $APP_ROLE"
    sed -i -r "s/export ZETA_MARATHON_ENV=.*\$/export ZETA_MARATHON_ENV=\"$APP_ID-$APP_ROLE.marathon.slave\"/" /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_$APP_ROLE.sh
    sed -i -r "s/export ZETA_MARATHON_PORT=.*\$/export ZETA_MARATHON_PORT=\"$APP_PORT\"/" /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_$APP_ROLE.sh
fi

ZETA_OPENLDAP_HOST=openldap-shared.marathon.slave.mesos
ZETA_OPENLDAP_PORT=389

cat > ${APP_HOME}/plugin-conf.json << EOJ
"ldap": {
    /*
     * the url property specifies the server, port and SSL setting of your directory.
     * Default port is 389 for plaintext or STARTTLS, and 636 for SSL.  If you want 
     * SSL, specify the protocol as 'ldaps:' rather than 'ldap:'
     */
    "url": "ldap://${ZETA_OPENLDAP_HOST}:${ZETA_OPENLDAP_PORT}",
    /*
     * base represents the domain your directory authenticates.  A domain of
     * example.com would normally be expressed in the form below, although note
     * that there is not necessarily a direct correlation between domains that 
     * might be part of an email address or username and the baseDN of the 
     * directory server.
     */
    "base": "dc=marathon,dc=mesos",

    /*
     * The dn property tells the plugin how to format a distinguished name for a user
     * that you want to authenticate.  The string {username} MUST exist in here and 
     * will be replaced by whatever the user submits as "username" in the login dialog.
     *
     * When the plugin calculates the DN to use to attempt authentication, it will
     * take the interpolated value here, suffixed with the userSubTree (if defined)
     * and the base property.  For example, the settings here and a submitted username
     * of 'fred' would cause a bind attempt using 'dn=uid=fred,ou=People,dc=example,dc=com'
     */
    "dn": "cn={username},ou=users,ou=zetashared",

    /*
     * The userSearch string is used following successful bind in order to obtain the
     * entire user record for the user logging in.  Similar to the 'dn' property above,
     * the supplied username will be substituted into the pattern below and the search
     * will be performed as shown against a search context of 'base' or (if defined)
     * the userSubTree section only.
     */
    "userSearch": "(&(cn={username})(objectClass=inetOrgPerson))",

    /* ---- the following properties are optional and can be left undefined ---- */

    /*
     * If you want to restrict the user searches and bind attempts to a particular 
     * org unit or other area of the LDAP directory, specify the sub tree here.  The
     * descriptions of earlier properties note where this definition may affect
     * behaviour.
     */
    "userSubTree": "ou=zetashared",

    /*
     * If your group memberships are specified by using "memberOf" attributes on the
     * user record, you don't need the following.  However, if your groups are defined 
     * as separate entities and membership is denoted by having all the usernames 
     * inside the group, then you do.  This is common for posixGroup type groups.
     * Specify the 'groupSearch' property as a pattern to find all groups that the 
     * user is a member of.
     */
    "groupSearch": "(&(memberUid={username})(objectClass=posixGroup))",

    /*
     * Similar to userSubTree but for the group entities
     */
    "groupSubTree": "cn=zeta${APP_ROLE}marathon,ou=groups,ou=zeta${APP_ROLE}"
}
EOJ

cat > ${APP_HOME}/run_marathon.sh << EOR
#!/bin/bash

mkdir -p ./plugins

mv ./${APP_LDAP_BASE_FILE} ./plugins/
HOST_IP=\$(\$MESOS_IP_DISCOVERY_COMMAND)
MARATHON_HOSTNAME=\$(\$MESOS_IP_DISCOVERY_COMMAND)
LIBPROCESS_IP=\$(\$MESOS_IP_DISCOVERY_COMMAND)

FRAMEWORKNAME="marathon$APP_ID"
MAR_PORT="$APP_PORT"
MAR_URL="https://\${FRAMEWORKNAME}-${APP_ROLE}.marathon.slave.mesos:\${MAR_PORT}"

\${JAVA_HOME}/bin/java \\
-Xmx${APP_JAVA_MEM}m \\
-jar "./$APP_VER/target/scala-2.11/marathon-assembly-${APP_VER_NUM}.jar" \\
--zk "zk://zk-1.zk:2181,zk-2.zk:2181,zk-3.zk:2181,zk-4.zk:2181,zk-5.zk:2181/\${FRAMEWORKNAME}" \\
--master "zk://zk-1.zk:2181,zk-2.zk:2181,zk-3.zk:2181,zk-4.zk:2181,zk-5.zk:2181/mesos" \\
--hostname "\$MARATHON_HOSTNAME" \\
--framework_name "\$FRAMEWORKNAME" \\
--max_tasks_per_offer 100 \\
--task_launch_timeout 86400000 \\
--decline_offer_duration 300000 \\
--revive_offers_for_new_apps \\
--zk_compression \\
--mesos_leader_ui_url "/mesos" \\
--enable_features "vips,task_killing,external_volumes" \\
--mesos_authentication_principal "dcos_marathon" \\
--mesos_user "root" \\
--webui_url "\$MAR_URL" \\
--mesos_role "$APP_ROLE" \\
--default_accepted_resource_roles "$APP_RESOURCES" \\
--disable_http \\
--https_port "$APP_PORT" \\
--ssl_keystore_path "${APP_HOME}/certs/myKeyStore.jks" \\
--plugin_dir "./plugins" \\
--plugin_conf "./plugin-conf.json"
EOR

chmod +x ${APP_HOME}/run_marathon.sh

APP_MARATHON_FILE="${APP_HOME}/marathon.json"

cat > ${APP_MARATHON_FILE} << EOF4
{
"id": "${APP_ROLE}/${APP_ID}",
"cmd": "./run_marathon.sh",
"cpus": ${APP_CPU},
"mem": ${APP_MEM},
"instances": 1,
"labels": {
    "PRODUCTION_READY":"True",
    "ZETAENV":"${APP_ROLE}",
    "CONTAINERIZER":"Mesos"
},
"env": {
"JAVA_HOME": "$JAVA_HOME",
"LD_LIBRARY_PATH": "/opt/mesosphere/lib",
"MESOS_ROLE": "${APP_ROLE}",
"MESOS_NATIVE_JAVA_LIBRARY": "/opt/mesosphere/lib/libmesos.so",
"MESOS_IP_DISCOVERY_COMMAND": "/opt/mesosphere/bin/detect_ip",
"MESOSPHERE_KEYSTORE_PASS":"$KEYSTOREPASS"
},
"ports":[],
"uris": ["file://${APP_BASE}", "file://${APP_LDAP_BASE}", "file://${APP_HOME}/run_marathon.sh", "file://${APP_HOME}/plugin-conf.json"]
}
EOF4


##########
# Provide instructions for next steps
echo ""
echo ""
echo "$APP_NAME instance ${APP_ID} installed at ${APP_HOME} and ready to go"
echo "To start please run: "
echo ""
echo "> ${APP_HOME}/start_instance.sh"
echo ""

