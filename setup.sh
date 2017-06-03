#!/bin/bash

DEPLOYDEV="$1"

HIFIBASEDIR="/opt/hifi"


if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ -d $HIFIBASEDIR ]; then
    echo "Please install into a new install."
    exit
fi


yum update -y
yum install -y epel-release centos-release-scl

yum groupinstall -y --enablerepo=epel "development tools"
yum install -y openssl-devel cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt* devtoolset-4-gcc-c++


function installHifiServer() {
    mkdir -p $HIFIBASEDIR/hifi-server

    git clone -b master --single-branch https://github.com/amvmoody/hifi-server.git $HIFIBASEDIR/hifi-server

    cd $HIFIBASEDIR/hifi-server
    LATEST=$(git describe --abbrev=0 --tags)
    git checkout tags/$LATEST

    cp $HIFIBASEDIR/hifi-server/setup/assignment-client.service /etc/systemd/system/assignment-client.service
    cp $HIFIBASEDIR/hifi-server/setup/domain-server.service /etc/systemd/system/domain-server.service
    cp $HIFIBASEDIR/hifi-server/setup/hifi /usr/local/bin/hifi

    chmod 755 /usr/local/bin/hifi
    if [[ $DEPLOYDEV =~ ^([Dd][Ee][Vv]|[Dd])$ ]]
    then
        sed -i '0,/PRODUCTION=true/s//PRODUCTION=false/' /usr/local/bin/hifi
    fi

}


function installHifi() {
    id -u hifi &>/dev/null || useradd hifi
    id -g hifi &>/dev/null || groupadd hifi


    function setPerms() {
        if [ -d "$HIFIBASEDIR/live" ]; then
            chown -R hifi:hifi $HIFIBASEDIR/live
        fi
    }


    mkdir -p $HIFIBASEDIR/live
    mkdir -p $HIFIBASEDIR/build
    mkdir -p $HIFIBASEDIR/source
    mkdir -p $HIFIBASEDIR/backups
    mkdir -p $HIFIBASEDIR/logs

    LATEST=""
    function gitClone() {
        git clone -b $1 --single-branch https://github.com/highfidelity/hifi.git $HIFIBASEDIR/source

        cd $HIFIBASEDIR/source
        LATEST=$(git describe --abbrev=0 --tags)
        git checkout tags/$LATEST

    }

    if [[ $DEPLOYDEV =~ ^([Dd][Ee][Vv]|[Dd])$ ]]
     then
        echo "#### DEV ####"
        gitClone master
        cd $HIFIBASEDIR/build

        cmake3 -DSERVER_ONLY=TRUE $HIFIBASEDIR/source
    else
        echo "#### PRODUCTION ####"
        gitClone stable
        cd $HIFIBASEDIR/build

        RELEASE_TYPE=PRODUCTION RELEASE_NUMBER=$(echo $LATEST | cut -d'-' -f2) cmake3 -DSERVER_ONLY=TRUE -DDCMAKE_BUILD_TYPE=Release $HIFIBASEDIR/source
    fi



    scl enable devtoolset-4 "make domain-server && make assignment-client"

    cp -R $HIFIBASEDIR/build/* $HIFIBASEDIR/live

    setPerms

    systemctl enable domain-server.service
    systemctl start domain-server.service
    systemctl enable assignment-client.service
    systemctl start assignment-client.service



}



function firewalldSetup() {

yum install firewalld -y

systemctl enable firewalld.service
systemctl start firewalld.service

firewall-cmd --permanent --zone=public --add-port=40100/tcp
firewall-cmd --permanent --zone=public --add-port=40101/tcp
firewall-cmd --permanent --zone=public --add-port=40102/tcp
firewall-cmd --permanent --zone=public --add-port=40103/tcp
firewall-cmd --permanent --zone=public --add-port=40104/tcp
firewall-cmd --permanent --zone=public --add-port=40105/tcp

firewall-cmd --permanent --zone=public --add-port=40100/udp
firewall-cmd --permanent --zone=public --add-port=40101/udp
firewall-cmd --permanent --zone=public --add-port=40102/udp
firewall-cmd --permanent --zone=public --add-port=40103/udp
firewall-cmd --permanent --zone=public --add-port=40104/udp
firewall-cmd --permanent --zone=public --add-port=40105/udp

systemctl restart firewalld.service

}

firewalldSetup

installHifiServer

installHifi

#this helps me gauge community interest, without it I have no idea how many are using it or if I should continue to update it.
curl -H "Content-Type: application/json" -X POST -d '{"type":"install","name":"hifi-server"}' https://api.midnightrift.com/pingback

crontab -l | { cat; echo "$((1 + RANDOM % 60)) 1 * * * /usr/local/bin/hifi --cron >> /opt/hifi/logs/cron.log"; } | crontab -