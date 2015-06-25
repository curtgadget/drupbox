#!/bin/bash

BOOTLOG=/var/log/provision.log
IS_SUB=0
log_status() {
    if [ "$IS_SUB" == "1" ]; then
        prefix="    "
        IS_SUB=0
    else
        prefix=""
    fi
    $@ >> $BOOTLOG 2>&1
    if [ "$?" == "0" ];then
        echo "$prefix""-> [OK]"
    else
        echo "$prefix"'-> [FAILED]' > /dev/stderr
    fi
}

log_msg(){
    printf "$1"
}
log_sub_msg(){
    IS_SUB=1
    printf "    $1"
}

echo "============================================="
echo "         Begin Provisioning"
echo "============================================="

log_msg "Preparing boot log file..."
log_status rm $BOOTLOG

APT_PACKAGES=(
curl
wget
build-essential
apache2
mysql-server
php5
php5-dev
php5-memcached
php5-xdebug
php5-mysql
php5-curl
php-pear
memcached
vim
git
unzip
ntp
openssh-server
phpmyadmin
screen
nodejs
)

# update apt repo
log_msg "updating apt repo..."
update_apt_repo(){
    apt-get update
    apt-get -y install python-software-properties
     export DEBIAN_FRONTEND=noninteractive
    add-apt-repository ppa:ondrej/php5-5.6
    add-apt-repository ppa:chris-lea/node.js
    add-apt-repository ppa:chris-lea/node.js-devel
    apt-get update
}
log_status update_apt_repo

echo "Installing apt packages..."
for p in ${APT_PACKAGES[@]}; do
    if [ -n $p ]; then
        log_sub_msg "$p"
        log_status apt-get -y -q install $p
    fi
done

# install composer
log_msg "installing composer..."
install_composer(){
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
}
log_status install_composer

log_msg "Setting up phpmyadmin"
setup_phpmyadmin(){
   sudo cp /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
   a2enconf phpmyadmin
}
log_status setup_phpmyadmin

# install drush
log_msg "Installing drush..."
install_drush(){
    /usr/local/bin/composer global require drush/drush:7.*
    echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.bashrc
    /usr/local/bin/composer global update
}
log_status install_drush

log_msg "Adding .bash_profile"
setup_bash_profile(){
    cp -f /vagrant/bash_profile /home/vagrant/.bash_profile
    source /home/vagrant/.bash_profile
}
log_status setup_bash_profile

log_msg "Apache Setup..."
setup_apache(){
    echo "DirectoryIndex index.php" > /var/www/html/.htaccess

    # Clean URLS.
    a2enmod rewrite
    sudo cp /vagrant/clean_urls.conf /etc/apache2/conf-available/
    a2enconf clean_urls
}
log_status setup_apache

log_msg "restarting services.."
restart_services(){
    service mysql restart
    service apache2 restart
}
log_status restart_services

echo "Provisioning complete"
