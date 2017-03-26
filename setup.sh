#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ ! -f /opt/hifi ]; then
    echo "Please install into a new install"
    exit
fi

function getRepo {

git fetch --tags

LATEST=$(git describe --abbrev=0 --tags)

echo "checking out " $LATEST
sleep 2
git checkout $LATEST

}



yum update -y

yum install -y epel-release
yum install -y --enablerepo=epel



yum groupinstall -y "development tools"
yum openssl-devel -y cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt*


id -u hifi &>/dev/null || useradd hifi
id -g hifi &>/dev/null || groupadd hifi


mkdir -p /opt/hifi/live
mkdir -p /opt/hifi/build
mkdir -p /opt/hifi/source
mkdir -p /opt/hifi/backups
mkdir -p /opt/hifi/logs




cd /opt/hifi
