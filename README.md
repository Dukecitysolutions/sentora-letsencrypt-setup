# Sentora LetsEncrypt installer

* Version: 0.1.2

## Description

**Sentora Letsencrypt install includes-**
* Installs Letsencrypt.
* Installs/Enables Apache mod_ssl.
* Creates Sentora control panel SSL for ( 90 Days ).
* Configures/Enables sentora control panel SSL Cert.
* Auto-renews SSL certs every Month at 1:00am with cron.

## Supports:
**- Sentora v.1.0.x - v.1.1.0**

## Downloading Sentora Letsencrypt and install
```
bash <(curl -L -Ss http://zppy-repo.dukecitysolutions.com/repo/letsencrypt/sentora_letsencrypt_setup.sh)
```

## Create SSL Certs manually with this command
**CentOs - Replace [SERVICE] with httpd**
**Ubuntu - Replace [SERVICE] with apache2**

**Parent Domians use code below - ex. YOUR-DOMAIN.COM**
```
service [SERVICE] stop
./letsencrypt-auto certonly --standalone -d [YOUR-DOMAIN] -d www.[YOUR-DOMAIN]
service [SERVICE] start
```

**Sub-Domains use code below - ex. SUB.YOUR-DOMAIN.COM**
```
service [SERVICE] stop
./letsencrypt-auto certonly --standalone -d [YOUR-DOMAIN]
service [SERVICE] start
``` 

## Getting support

We are currently building a support page to help with any issues. Please check back soon for updates.
 
