#!/bin/bash

if [[ "$OS" = "CentOs" ]]; then

	APACHE_START="systemctl start httpd"
	APACHE_STOP="systemctl stop httpd"

elif [[ "$OS" = "Ubuntu" ]]; then

	APACHE_START="service apache2 start"
	APACHE_STOP="service apache2 stop"

fi

# Stop apache
$APACHE_STOP

# Renew Panel Cert
cd letsencrypt
./letsencrypt-auto renew

# Stop apache
$APACHE_START