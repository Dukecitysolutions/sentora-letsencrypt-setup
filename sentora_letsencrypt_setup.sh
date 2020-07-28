#!/bin/bash

# Official Sentora Letsencypt Automated Installation Script
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

PANEL_PATH="/etc/sentora"
SENTORA_VERSION=$($PANEL_PATH/panel/bin/setso --show db_version)

# Bash Color
red='\e[0;31m'
green='\e[0;32m'
yellow='\e[0;33m'
bold='\e[1m'
underlined='\e[4m'
NC='\e[0m' # No Color
COLUMNS=$(tput cols)

# -------------------------------------------------------------------------------
# Installer Logging
#--- Set custom logging methods so we create a log file in the current working directory.

	logfile=$(/var/sentora/logs/letsencrypt-renew.log)
	touch "$logfile"
	exec > >(tee "$logfile")
	exec 2>&1
# -------------------------------------------------------------------------------	

echo ""
echo "############################################################"
echo -e "\nWelcome to the Official Letsencrypt Installer for Sentora v1.0.0-1.1.0 By: Anthony D. #"
echo "############################################################"

echo -e "\nChecking that minimal requirements are ok"

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

echo "Detected : $OS  $VER  $ARCH"

if [[ "$OS" = "CentOs" && ("$VER" = "6" || "$VER" = "7" ) || 
      "$OS" = "Ubuntu" && ( "$VER" = "14.04" || "$VER" = "16.04" || "$VER" = "18.04" || "$VER" = "20.04" ) ]] ; then
    echo "- Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1
fi

# Set OS package installer/remover/service commands
if [[ "$OS" = "CentOs" ]] ; then
	PACKAGE_INSTALLER="yum -y -q install"
	APACHE_START="systemctl start httpd"
	APACHE_STOP="systemctl stop httpd"
	APACHE_RESTART="systemctl restart httpd"
	CRON_RESTART="systemctl restart cron"
elif [[ "$OS" = "Ubuntu" ]] ; then
	PACKAGE_INSTALLER="apt-get -yqq install"
	APACHE_START="service apache2 start"
	APACHE_STOP="service apache2 stop"
	APACHE_RESTART="service apache2 restart"
	CRON_RESTART="service cron restart"
fi

###### Start install here

if [[ "$OS" = "CentOs" ]]; then

#####################################################################
echo -e "\n--- Detected - $OS $VER - Installing MOD_SSL & Letsencrypt Preconf..."
#####################################################################

	# Install MOD_SSL & Openssl
	$PACKAGE_INSTALLER openssl
	$PACKAGE_INSTALLER mod_ssl
	
	# Remove Listen 443 from ssl.config. Listen is controlled by Sentora vhost config file.		
	sed -i 's|Listen 443|#Listen 443|g' /etc/httpd/conf.d/ssl.conf
	
	# Patch Apache mod_ssl #listen 443 line for Sentora v1.0.3 if needed
	#if [ "$SENTORA_VERSION" == "1.0.3" ]; then
	#	echo "Found Sentora v1.0.3. Disabling/Patching Apache mod_ssl Listen line"
	#	sed -i 's|*Listen 443|#Listen 443|g' /etc/httpd/conf.d/ssl.conf
	#else
	#	echo "Found Sentora v1.0.3.1-BETA"
	#	#Do nothing for 
	#fi
	
elif [[ "$OS" = "Ubuntu" ]]; then	

#####################################################################
echo -e "\n--- Detected - $OS $VER - Installing MOD_SSL & Letsencrypt Preconf..."
#####################################################################

	# Install MOD_SSL
	$PACKAGE_INSTALLER mod_ssl
	
	# Check and enable MOD_SSL
	a2enmod ssl
	
fi

#####################################################################
echo -e "\n--- Installing Letsencrypt..."
#####################################################################

$PACKAGE_INSTALLER git
rm -r ~/letsencrypt
git clone https://github.com/letsencrypt/letsencrypt
cd letsencrypt
./letsencrypt-auto --help

#####################################################################
# Setup Sentora panel with Letencrypt cert
echo -e "\n--- Setting up Controlpanel letsencrypt..."
#####################################################################

function set_panel_ssl {

	# Get Sentora panel url for DB
	SENTORA_DOMAIN=$($PANEL_PATH/panel/bin/setso --show sentora_domain)
	
	# Create Sentora control panel Letsencrypt cert
	$APACHE_STOP
	./letsencrypt-auto certonly --standalone -d $SENTORA_DOMAIN
	$APACHE_START

	# Add SSL config to control panels vhost entry
	SSL_CONFIG="$(cat <<-EOF
	SSLEngine on
	SSLProtocol ALL -SSLv2 -SSLv3
	SSLHonorCipherOrder On
	SSLCipherSuite ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
	SSLCertificateFile /etc/letsencrypt/live/$SENTORA_DOMAIN/cert.pem
	SSLCertificateKeyFile /etc/letsencrypt/live/$SENTORA_DOMAIN/privkey.pem
	SSLCertificateChainFile /etc/letsencrypt/live/$SENTORA_DOMAIN/chain.pem
	# Keeping bellow for future upgrades.
	# Requires Apache >= 2.4
	SSLCompression off
	EOF
	)"

	# Check if domain cert was added before we continue.
	FILE="/etc/letsencrypt/live/$SENTORA_DOMAIN"
	if [ -f "$FILE" ]; then
	
		# Set control panel SSL config according to version. Looking in to this for different setups versions.	
		DIR="/etc/sentora/configs/php/sp"
		if [ -d "$DIR" ]; then
			echo "Found Sentora v.1.1.x"
			$PANEL_PATH/panel/bin/setso --set panel_ssl_tx "$SSL_CONFIG"
		else
			echo "Found Sentora v.1.0.x"
			$PANEL_PATH/panel/bin/setso --set global_zpcustom "$SSL_CONFIG"
		fi
	
		#########################################################################################################
		# Download/set need files from Github for Auto renew panel SSL
		#########################################################################################################
		
		# Install GIT
		$PACKAGE_INSTALLER git
		
		# CHECK for old installer files and delete them
		if [ -d "~/sentora-letsencrypt" ]; then
			rm -rf  ~/sentora-letsencrypt
    		rm -rf  /etc/sentora/configs/sentora-letsencrypt
		fi
		
		# Download/Clone Needed files for setup
		git clone https://github.com/Dukecitysolutions/sentora-letsencrypt-setup sentora-letsencrypt
		cd sentora-letsencrypt
		
		# Delete Letsencrypt config folder contents for NEW updated files
		if [ -d "/etc/sentora/configs/letsencrypt" ]; then
    		rm -rf  /etc/sentora/configs/letsencrypt
		fi
		
		# Copy/setup Auto-renew files for panel cert renewal
		mkdir -p /etc/sentora/configs/letsencrypt
		cp -r preconf/letsencrypt/* /etc/sentora/configs/letsencrypt/
		cp -r preconf/letsencrypt/letsencrypt-cron /etc/cron.d/
		
		# Make auto-renew script executable
		chmod +x /etc/sentora/configs/letsencrypt/letsencrypt-renew.sh
		
		# Clean up files after install
		rm -r ~/sentora-letsencrypt
		
		# Restart Cron service
		$CRON_RESTART
	
		#########################################################################################################
		# Set and Run Zdaemon
		#########################################################################################################
		
		# Set apache daemon to build vhosts file.
		$PANEL_PATH/panel/bin/setso --set apache_changed "true"
	
		# Run Daemon & restart Apache/httpd
		php -d "sp.configuration_file=/etc/sentora/configs/php/sp/sentora.rules" -q /etc/sentora/panel/bin/daemon.php
		$APACHE_RESTART
		
	else
	
		# If something went wrong stop script and let user know to check log in root folder
		echo -e "\n- Looks like something went wrong. Please check log in ROOT folder, correct issues and try again."
		exit
		
	fi
	
} # End function

while true; do
read -p "Would you like to setup Sentora control panel with a SSL cert? Press (y/n) to Continue to create Sentora panel cert" choice
case "$choice" in 
  y|Y ) set_panel_ssl;break;;
  n|N ) break;;
  * ) echo "Invalid entry. Please enter (y/n) - (Yes/No)";;
esac
done

#####################################################################

# Clean up files downloaded for install/update
rm -r ~/sentora-letsencrypt

#####################################################################

# All done
echo -e "\nAll done installing Letsencypt. Enjoy!!!"
