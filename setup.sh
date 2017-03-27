#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ ! -f /opt/hifi ]; then
    echo "Please install into a new install"
    exit
fi


yum update -y

yum install -y epel-release
yum install -y --enablerepo=epel



yum groupinstall -y "development tools"
yum openssl-devel -y cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt*




function doInstall() {
    id -u hifi &>/dev/null || useradd hifi
    id -g hifi &>/dev/null || groupadd hifi

    HIFIBASEDIR="/opt/hifi"
    function setPerms()  {
      if [ -d "$HIFIBASEDIR/live" ]; then
        chown -R hifi:hifi $HIFIBASEDIR/live
      fi
    }
    if [ ! -f /opt/hifi ]; then
        echo "Already Installed."
        exit
    fi

    mkdir -p /opt/hifi/live
    mkdir -p /opt/hifi/build
    mkdir -p /opt/hifi/source
    mkdir -p /opt/hifi/backups
    mkdir -p /opt/hifi/logs

    cd $HIFIBASEDIR/source
    git fetch --tags
    LATEST=$(git describe --abbrev=0 --tags)
    git checkout $LATEST

    cmake3 -B$HIFIBASEDIR/build -DGET_LIBOVR=1
    cd -
    cd $HIFIBASEDIR/build

    make domain-server && make assignment-client
    cd -


    cp $HIFIBASEDIR/build/hifi.service /etc/systemd/system/hifi.service
    cp $HIFIBASEDIR/build/* $HIFIBASEDIR/live
    cp $HIFIBASEDIR/build/hifi /usr/local/bin/hifi


    setPerms
    systemctl enable hifi.service
    systemctl start hifi.service
}


doInstall