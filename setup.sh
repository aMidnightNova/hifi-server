#!/bin/bash

DEPLOYDEV="$1"

HIFIBASEDIR="/opt/hifi"
export QT_CMAKE_PREFIX_PATH=/opt/qt-5.9.1/lib/cmake

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi


if [ -d $HIFIBASEDIR ]; then
    echo "Please install into a new install."
    exit
fi

CPU_CORES=$(grep -i processor /proc/cpuinfo | wc -l)
if (( $CPU_CORES > 1 )); then
    CPU_CORES=$(($CPU_CORES - 1));
fi


yum update -y
yum install -y epel-release centos-release-scl

yum groupinstall -y --enablerepo=epel "development tools"
yum install -y openssl-devel cmake3 glew-devel git wget libXmu-* libXi-devel libXrandr libXrandr-devel qt5-qt* devtoolset-7-gcc devtoolset-7-gcc-c++ wget


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

    VERSIONTEMP=$(echo $LATEST | cut -d'-' -f1)
    echo "HIFI_SERVER_VERSION=${VERSIONTEMP:1}" > $HIFIBASEDIR/env.conf
}


function getQt() {
    cd /opt/
    wget  https://download.qt.io/archive/qt/5.9/5.9.1/single/qt-everywhere-opensource-src-5.9.1.tar.xz
    mkdir /opt/qt-5.9.1
    tar xvf qt-everywhere-opensource-src-5.9.1.tar.xz
    cd qt-everywhere-opensource-src-5.9.1
    ./configure -confirm-license -opensource -release -prefix /opt/qt-5.9.1

    make -j$CPU_CORES && make install

    cd /opt/

    rm -rf qt-everywhere-opensource-src-5.9.1
    rm -f qt-everywhere-opensource-src-5.9.1.tar.xz



}

function installHifi() {
    id -u hifi &>/dev/null || useradd hifi
    id -g hifi &>/dev/null || groupadd hifi


    function setPerms() {
        if [ -d "$HIFIBASEDIR/live" ]; then
            chown -R hifi:hifi $HIFIBASEDIR/live
        fi
    }


    mkdir -p $HIFIBASEDIR/live $HIFIBASEDIR/live/build $HIFIBASEDIR/live/server-files
    mkdir -p $HIFIBASEDIR/build
    mkdir -p $HIFIBASEDIR/source
    mkdir -p $HIFIBASEDIR/backup $HIFIBASEDIR/backup/backups $HIFIBASEDIR/backup/temp
    mkdir -p $HIFIBASEDIR/logs

    LATEST=""
    function gitClone() {
        git clone -b $1 --single-branch https://github.com/highfidelity/hifi.git $HIFIBASEDIR/source

        cd $HIFIBASEDIR/source
        LATEST=$(git describe --abbrev=0 --tags)
        git checkout tags/$LATEST

    }

    source scl_source enable devtoolset-7

    if [[ $DEPLOYDEV =~ ^([Dd][Ee][Vv]|[Dd])$ ]]
        then
            echo "#### DEV ####"
            gitClone master
            cd $HIFIBASEDIR/build
            echo "PRODUCTION=false" >> $HIFIBASEDIR/env.conf

            RELEASE_NUMBER=$(echo $LATEST | cut -d'-' -f2) cmake3 -DSERVER_ONLY=TRUE $HIFIBASEDIR/source
        else
            echo "#### PRODUCTION ####"
            gitClone stable
            cd $HIFIBASEDIR/build
            echo "PRODUCTION=true" >> $HIFIBASEDIR/env.conf

            BRANCH=stable BUILD_BRANCH=stable RELEASE_TYPE=PRODUCTION RELEASE_NUMBER=$(echo $LATEST | cut -d'-' -f2) \
            cmake3 -DSERVER_ONLY=TRUE -DCMAKE_BUILD_TYPE=Release $HIFIBASEDIR/source
    fi

    echo "QT_CMAKE_PREFIX_PATH=$QT_CMAKE_PREFIX_PATH" >> $HIFIBASEDIR/env.conf

    make -j$CPU_CORES domain-server && make -j$CPU_CORES assignment-client

    cp -R $HIFIBASEDIR/build/* $HIFIBASEDIR/live/build

    setPerms

    systemctl enable domain-server.service
    systemctl start domain-server.service
    systemctl enable assignment-client.service
    systemctl start assignment-client.service

    sleep 2

    systemctl stop domain-server.service
    systemctl stop assignment-client.service


    if [[ $DEPLOYDEV =~ ^([Dd][Ee][Vv]|[Dd])$ ]]
        then
            mv /home/hifi/.local/share/High\ Fidelity\ -\ dev/* $HIFIBASEDIR/live/server-files
            rm -rf /home/hifi/.local/share/High\ Fidelity\ -\ dev
        else
            mv /home/hifi/.local/share/High\ Fidelity/* $HIFIBASEDIR/live/server-files
            rm -rf /home/hifi/.local/share/High\ Fidelity
    fi

    ln -s $HIFIBASEDIR/live/server-files /home/hifi/.local/share/High\ Fidelity\ -\ dev
    ln -s $HIFIBASEDIR/live/server-files /home/hifi/.local/share/High\ Fidelity

    systemctl start domain-server.service
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

getQt

installHifi

#this helps me gauge community interest, without it I have no idea how many are using it or if I should continue to update it.
curl -H "Content-Type: application/json" -X POST -d '{"type":"install","name":"hifi-server"}' https://api.midnightrift.com/pingback

crontab -l | { cat; echo "$((1 + RANDOM % 60)) 1 * * * /usr/local/bin/hifi --cron >> /opt/hifi/logs/cron.log"; } | crontab -