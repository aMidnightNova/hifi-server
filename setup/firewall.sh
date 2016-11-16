#!/bin/bash

yum install -y firewalld

crontab -l | { cat; echo "12 5 2 * * certbot renew > /opt/cert.txt"; } | crontab -