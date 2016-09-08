#!/bin/bash

CLUSTERNAME=$(ls /mapr)

. /mapr/$CLUSTERNAME/zeta/kstore/env/zeta_shared.sh

APP_NAME="mariadb"

APP_IMG="${ZETA_DOCKER_REG_URL}/${APP_NAME}"

BUILD_TMP="./tmpbuilder"

echo "Checking Docker"
DOCKER_CHK=$(sudo docker ps)
if [ "$DOCKER_CHK" == "" ]; then
    echo "It doesn't appear your user has the ability to run Docker commands"
    exit 1
fi


IMG_CHK=$(sudo docker images|grep "\/${APP_NAME}")
if [ "$IMG_CHK" != "" ]; then
    echo "A $APP_NAME image was already identified. Do you wish to rebuild?"
    read -e -p "Rebuild? " -i "N" BUILD
else
    BUILD="Y"
fi
if [ "$BUILD" == "Y" ]; then
    rm -rf $BUILD_TMP
    mkdir -p $BUILD_TMP
    cd $BUILD_TMP

cat > Dockerfile << EOL
FROM ${ZETA_DOCKER_REG_URL}/maprbase

RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db && \
    echo 'deb http://mirrors.syringanetworks.net/mariadb/repo/5.5/ubuntu trusty main' >> /etc/apt/sources.list && \
    echo 'deb-src http://mirrors.syringanetworks.net/mariadb/repo/5.5/ubuntu trusty main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y mariadb-server pwgen git && \
    rm -rf /var/lib/mysql/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#change bind address to 0.0.0.0
RUN sed -i -r 's/bind-address.*$/bind-address = 0.0.0.0/' /etc/mysql/my.cnf

#Update the buffer pool to use more memory (in this case 1024M of ram) Update as needed.
RUN sed -i -r 's/innodb_buffer_pool_size.*$/innodb_buffer_pool_size = 1024M/' /etc/mysql/my.cnf

# Need to set binlog

RUN sed -i -r 's/max_binlog_size         = 100M/max_binlog_size         = 100M\nbinlog_format = MIXED\n/' /etc/mysql/my.cnf

# Pull the current version of the mesos-lockfile. This should work as is no changes.

ADD lockfile.sh /lockfile.sh
ADD create_mariadb_admin_user.sh /create_mariadb_admin_user.sh
ADD run.sh /run.sh

RUN chmod 775 /*.sh

#Added to avoid in container connection to the database with mysql client error message "TERM environment variable not set"
ENV TERM dumb

EXPOSE 3306
CMD ["/lockfile.sh"]
EOL

cat > create_mariadb_admin_user.sh << EOL1
#!/bin/bash

/usr/bin/mysqld_safe 2>&1 &

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MariaDB service startup"
    sleep 5
    mysql -uroot -e "status" > /dev/null 2>&1
    RET=\$?
done


PASS=\${MARIADB_PASS:-\$(pwgen -s 12 1)}
_word=\$( [ \${MARIADB_PASS} ] && echo "preset" || echo "random" )
echo "=> Creating MariaDB admin user with \${_word} password"

mysql -uroot -e "CREATE USER 'admin'@'%' IDENTIFIED BY '\$PASS'"
mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION"

echo "=> Done!"

cat > /creds/creds.txt << EOL10
========================================================================
You can now connect to this MariaDB Server using:

    mysql -uadmin -p\$PASS -h<host> -P<port>

Please remember to change the above password as soon as possible!
MariaDB user 'root' has no password but only allows local connections
========================================================================
EOL10

mysqladmin -uroot shutdown
EOL1

cat  > run.sh << EOL2
#!/bin/bash

VOLUME_HOME="/var/lib/mysql"

if [[ ! -d \$VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MariaDB volume is detected in \$VOLUME_HOME"
    echo "=> Installing MariaDB ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"
    /create_mariadb_admin_user.sh
else
    echo "=> Using an existing volume of MariaDB"
fi

exec mysqld_safe

EOL2

cat > lockfile.sh << EOL3
#!/bin/bash

#The location the lock will be attempted in
LOCKROOT="/lock"
LOCKDIRNAME="lock"
LOCKFILENAME="mylock.lck"

#This is the command to run if we get the lock.
RUNCMD="/run.sh"

#Number of seconds to consider the Lock stale, this could be application dependent.
LOCKTIMEOUT=60
SLEEPLOOP=30

LOCKDIR=\${LOCKROOT}/\${LOCKDIRNAME}
LOCKFILE=\${LOCKDIR}/\${LOCKFILENAME}



if mkdir "\${LOCKDIR}" &>/dev/null; then
    echo "No Lockdir. Our lock"
    # This means we created the dir!
    # The lock is ours
    # Run a sleep loop that puts the file in the directory
    while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
    #Now run the real shell scrip
    \$RUNCMD
else
    #Pause to allow another lock to start
    sleep 1
    if [ -e "\$LOCKFILE" ]; then
        echo "lock dir and lock file Checking Stats"
        CURTIME=\`date +%s\`
        FILETIME=\`cat \$LOCKFILE\`
        DIFFTIME=\$((\$CURTIME-\$FILETIME))
        echo "Filetime \$FILETIME"
        echo "Curtime \$CURTIME"
        echo "Difftime \$DIFFTIME"

        if [ "\$DIFFTIME" -gt "\$LOCKTIMEOUT" ]; then
            echo "Time is greater then Timeout We are taking Lock"
            # We should take the lock! First we remove the current directory because we want to be atomic
            rm -rf \$LOCKDIR
            if mkdir "\${LOCKDIR}" &>/dev/null; then
                while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
                \$RUNCMD
            else
                echo "Cannot Establish Lock file"
                exit 1
            fi
        else
            # The lock is not ours.
            echo "Cannot Estblish Lock file - Active "
            exit 1
        fi
    else
        # We get to be the locker. However, we need to delete the directory and recreate so we can be all atomic about
        rm -rf \$LOCKDIR
        if mkdir "\${LOCKDIR}" &>/dev/null; then
            while true; do date +%s > \$LOCKFILE ; sleep \$SLEEPLOOP; done &
            \$RUNCMD
        else
            echo "Cannot Establish Lock file - Issue"
            exit 1
        fi
    fi
fi
EOL3

    echo "Building Docker Image"
    sudo docker build -t $APP_IMG .
    sudo docker push $APP_IMG
    cd ..
    rm -rf $BUILD_TMP
else
    echo "Will not rebuild"
fi


echo ""
echo "$APP_NAME Image pushed to cluster shared docker and ready to role at $APP_IMG"
echo ""
