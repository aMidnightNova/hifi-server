#!/bin/bash

HIFIBASEDIR="/opt/hifi"

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ -d $HIFIBASEDIR ]; then
    echo "Please install into a new install"
    exit
fi


yum update -y

yum install -y epel-release
yum install -y --enablerepo=epel



yum groupinstall -y "development tools"
yum install -y openssl-devel cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt*


function installHifiServer() {
    mkdir -p $HIFIBASEDIR/hifi-server

    git clone https://github.com/amvmoody/hifi-server.git $HIFIBASEDIR/hifi-server
    cp $HIFIBASEDIR/hifi-server/setup/assignment-client.service /etc/systemd/system/assignment-client.service
    cp $HIFIBASEDIR/hifi-server/setup/domain-server.service /etc/systemd/system/domain-server.service
    cp $HIFIBASEDIR/hifi-server/setup/hifi /usr/local/bin/hifi

}


function installHifi() {
    id -u hifi &>/dev/null || useradd hifi
    id -g hifi &>/dev/null || groupadd hifi


    function setPerms()  {
      if [ -d "$HIFIBASEDIR/live" ]; then
        chown -R hifi:hifi $HIFIBASEDIR/live
      fi
    }


    mkdir -p $HIFIBASEDIR/live
    mkdir -p $HIFIBASEDIR/build
    mkdir -p $HIFIBASEDIR/source
    mkdir -p $HIFIBASEDIR/backups
    mkdir -p $HIFIBASEDIR/logs

    git clone https://github.com/highfidelity/hifi.git $HIFIBASEDIR/source

    cd $HIFIBASEDIR/source

    git fetch --tags
    LATEST=$(git describe --abbrev=0 --tags)
    git checkout tags/$LATEST

    cd $HIFIBASEDIR/build
    cmake3 -DGET_LIBOVR=1 $HIFIBASEDIR/source

    make domain-server && make assignment-client


    cp -R $HIFIBASEDIR/build/* $HIFIBASEDIR/live



    setPerms
    systemctl enable hifi.service
    systemctl start hifi.service
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