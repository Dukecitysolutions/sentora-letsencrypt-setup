#!/bin/bash

# Official Sentora Letsencypt Automated Cert Renew Script
# =============================================
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Supported Operating Systems: 
# CentOS 6.*/7.*/8.* Minimal, 
# Ubuntu server 14.04/16.04/18.04/20.04 
# Debian 8.*/9.*/10.* COMING SOON!!!
# 32bit and 64bit
#
# Created by:
#
#   Anthony DeBeaulieu (anthony.d@sentora.org)
#

# -------------------------------------------------------------------------------
# Letsencypt renewal Logging
#--- Set custom logging methods so we create a log file in the current working directory.

	logfile="/var/sentora/logs/letsencrypt-renew.log"
	touch "$logfile"
	exec > >(tee "$logfile")
	exec 2>&1
# -------------------------------------------------------------------------------

# Set Date/Time stamp for logs
NOW=$(date)

echo -e "\n-- Start Timestamp: $NOW"

echo -e "\n-- Starting LetsEncrypt Auto-Renewal process...\n"

# Ensure the OS is compatible with the launcher
if [ -f /etc/centos-release ]; then
    OS="CentOs"
    VERFULL=$(sed 's/^.*release //;s/ (Fin.*$//' /etc/centos-release)
    VER=${VERFULL:0:1} # return 6 or 7
elif [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/')
else
    OS=$(uname -s)
    VER=$(uname -r)
fi
ARCH=$(uname -m)

echo "- Detected : $OS  $VER  $ARCH"

if [[ "$OS" = "CentOs" && ("$VER" = "6" || "$VER" = "7" || "$VER" = "8" ) || 
      "$OS" = "Ubuntu" && ( "$VER" = "14.04" || "$VER" = "16.04" || "$VER" = "18.04" || "$VER" = "20.04" ) ||
      "$OS" = "debian" && ( "$VER" = "7" || "$VER" = "8" || "$VER" = "9" )]] ; then
    echo "- Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1
fi

# Set OS package installer/remover/service commands
if [[ "$OS" = "CentOs" ]]; then
	APACHE_START="service httpd start"
	APACHE_STOP="service httpd stop"
elif [[ "$OS" = "Ubuntu" || "$OS" = "Debian" ]]; then
	APACHE_START="systemctl start apache2"
	APACHE_STOP="systemctl stop apache2"
fi

# -------------------------------------------------------------------------------

### Start auto-renew script here

# Stop Apache/Httpd service & renew certs
echo -e "\n-- Stopping Apache services for renewal with HTTPS port :443..."
$APACHE_STOP

# Renew all certs for Letsencrypt
echo -e "\n-- Renewing LetsEncrpt Certs..."
cd ~/letsencrypt
./letsencrypt-auto renew # This is a LIVE RUN setting- for PRODUCTION 
#./letsencrypt-auto renew --dry-run # This is a DRY RUN setting - for TESTING

# Start Apache/Httpd services
echo -e "\n-- Starting Apache services..."
$APACHE_START

echo -e "\n-- Finish Timestamp: $NOW"

echo -e "\n#######################################################################"