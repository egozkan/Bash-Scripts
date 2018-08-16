#!/bin/bash

# A bash script for letsencrypt certification renewal. This script was tested on CentOS 7 with nginx and php-fpm installed.

########################################
#VARIABLES
########################################

certificate_path="/etc/nginx/ssl"
domain_name="your_domain_name"
domain_name_with_extension="your_domain_name.com"
remaining_days_to_renew=7


########################################
#DO NOT EDIT FOLLOWING LINES
########################################

#Certificate renewal information log file
renew_log_file="/tmp/"$domain_name_with_extension"_renew.log"

#Today's date for logging and file backuping
current_date=$(date +%F_%H-%M)

#Find out how many days remaining to certificate expiration
expire_date=$(openssl x509 -enddate -noout -in "$certificate_path"/"$domain_name".crt | awk -F'=' '{print $2}')

#Difference between today and certification expiration date
difference=$((($(date +%s --date "$expire_date")-$(date +%s --date "$date"))/(86400)))

#Init scripts for CentOS 7
php_fpm_start_script="systemctl start php-fpm.service"
php_fpm_stop_script="systemctl stop php-fpm.service"
nginx_start_script="systemctl start nginx.service"
nginx_stop_script="systemctl stop nginx.service"


if [ "$difference" -lt "$remaining_days_to_renew" ];then
 
	#Stop php-fpm, if fails exit
	$php_fpm_stop_script || exit 20

	#Stop nginx, if fails exit
	$nginx_stop_script || exit 30

        #Backup old certificate
	if [[ ! -d "$certificate_path"/bck ]]; then
        	mkdir -p "$certificate_path"/bck
	fi

	cp $certificate_path/"$domain_name".crt $certificate_path/bck/"$domain_name".crt_"$current_date"
	cp $certificate_path/"$domain_name".key $certificate_path/bck/"$domain_name".key_"$current_date"

 
	#Renew certificate
	echo "====================== $current_date ======================" >> $renew_log_file
	/opt/letsencrypt/letsencrypt-auto certonly --standalone --renew-by-default -d $domain_name_with_extension -d www."$domain_name_with_extension" >> $renew_log_file

	#Copy renewed certificate to certificate path
	cp /etc/letsencrypt/live/"$domain_name_with_extension"/fullchain.pem $certificate_path
	cp /etc/letsencrypt/live/"$domain_name_with_extension"/privkey.pem $certificate_path

        #Rename by domain name
	mv -f "$certificate_path"/fullchain.pem "$certificate_path"/"$domain_name".crt
	mv -f "$certificate_path"/privkey.pem "$certificate_path"/"$domain_name".key

        #Start php-fpm and nginx
	$php_fpm_start_script && $nginx_start_script


else
	#Exit if difference is greater then remaining_days_to_renew variable
	exit 1
fi
