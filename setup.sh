#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ ! -f /usr/bin/hifi ]; then
    echo "Please install into a new install"
    exit
fi

function handelgitclone {

# Get new tags from remote
git fetch --tags

# Get latest tag name
LATESTTAG=$(git describe --tags `git rev-list --tags --max-count=1`)

# Checkout latest tag
echo "checking out " $LATESTTAG
git checkout $LATESTTAG

}

# list of needed software yum will handel the installing

ech0 "Updating system if needed."
sleep 2
yum update -y
echo "Installing epel repo."
sleep 2
yum install -y epel-release
yum install -y --enablerepo=epel
echo "Installing dependencies."
sleep 2
yum groupinstall "development tools" -y
yum openssl-devel cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt* -y


##create the user hifi
id -u hifi &>/dev/null || useradd hifi

mkdir -p /opt/hifi/source


cd /opt/hifi
