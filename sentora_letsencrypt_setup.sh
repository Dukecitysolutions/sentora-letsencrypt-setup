#!/bin/bash

PANEL_PATH="/etc/sentora"

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

	logfile=$(date +%Y-%m-%d_%H.%M.%S_sentora_letsencrypt_install.log)
	touch "$logfile"
	exec > >(tee "$logfile")
	exec 2>&1
# -------------------------------------------------------------------------------	

echo ""
echo "############################################################"
echo "\nLetsencrypt for Sentora 1.0.0 or 1.0.3 By: Anthony D. #"
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
      "$OS" = "Ubuntu" && ( "$VER" = "14.04" || "$VER" = "16.04" || "$VER" = "18.04" ) ]] ; then
    echo "- Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1
fi

#####################################################################

if [[ "$OS" = "CentOs" ]]; then

	PACKAGE_INSTALLER="yum -y -q install"
	APACHE_START="systemctl start httpd"
	APACHE_STOP="systemctl stop httpd"

	$PACKAGE_INSTALLER openssl

	$PACKAGE_INSTALLER mod_ssl
	
	# check mod_ssl is enabled
	#a2enmod ssl
		
###### Patch apache mod_ssl #listen 443 line 

	#sed -i 's|Listen 443|#Listen 443|g' /etc/httpd/conf.d/ssl.conf

elif [[ "$OS" = "Ubuntu" ]]; then

	PACKAGE_INSTALLER="apt-get -yqq install"
	APACHE_START="service apache2 start"
	APACHE_STOP="service apache2 stop"

	$PACKAGE_INSTALLER mod_ssl
	
	# check mod_ssl is enabled
	a2enmod ssl

fi

#####################################################################
echo -e "\nInstalling letsencrypt..."
#####################################################################

$PACKAGE_INSTALLER git
git clone https://github.com/letsencrypt/letsencrypt
cd letsencrypt
./letsencrypt-auto --help

#####################################################################
# Setup Sentora panel with Letencrypt cert
echo -e "\nSetting up Controlpanel letsencrypt..."
#####################################################################
# Coming soon!!!

function setpanel_ssl {
	
	# Get Sentora panel url
	# find a way to add url to a variable this might work
	SENTORA_DOMAIN=$($PANEL_PATH/panel/bin/setso --show sentora_domain)
	
	# Create controlpanel letsencrypt cert
	$APACHE_STOP
	./letsencrypt-auto certonly --standalone -d $SENTORA_DOMAIN
	$APACHE_START

	# Add ssl config to panels vhost entry
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

	# Check if domain cert was added to continue.
	file="/etc/letsencrypt/live/$SENTORA_DOMAIN"
	if [ -f "$file" ]; then
	
		#looking in to this for different setups
		dir="/etc/sentora/configs/php"
		if [ -d "$dir" ]; then
			echo "Found Sentora v1.0.3.1-BETA"
			$PANEL_PATH/panel/bin/setso --set panel_ssl_tx "$SSL_CONFIG"
		else
			echo "Found Sentora v1.0.3."
			$PANEL_PATH/panel/bin/setso --set global_zpcustom "$SSL_CONFIG"
		fi
	
		# Set apache daemon to build vhosts file.
		$PANEL_PATH/panel/bin/setso --set apache_changed "true"
	
		# Run Daemon
		php -d "sp.configuration_file=/etc/sentora/configs/php/sp/sentora.rules" -q /etc/sentora/panel/bin/daemon.php
		service apache2 restart
	else
		echo -e "\nLooks like something went wrong. Please check log, correct issue and try again."
		exit
	fi
	
} # End function

while true; do
read -p "Would you like to setup control panel with a SSL cert? Continue create panel cert? (y/n)?" choice
case "$choice" in 
  y|Y ) setpanel_ssl;break;;
  n|N ) break;;
  * ) echo "invalid";;
esac
done


#####################################################################

# All done
echo -e "\nAll done enjoy!!!"


