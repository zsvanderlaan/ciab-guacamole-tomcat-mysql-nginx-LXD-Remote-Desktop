#!/bin/bash


# NOTE:  Execute this Script as SUDO or ROOT .. NOT as a normal UserID

# Source:
# http://chari.titanium.ee/script-to-install-guacamole/
# 
# Guacamole installation
# Supports Ubuntu 14.04,15.10 and Debian wheezy,jessie
# 32 and 64 bit
# Script to be run as sudo/root
# ver 1.5
# To be run on a FRESH OS install
# Do not install anything other than base OS
# Bharath Chari 2016
# http://chari.titanium.ee
# Updated 03-Feb-2016
 
 
# Variables for guacamole/mysql connector versions are set here.  As of 3/10/2016 these are the latest versions.

GUAC_VER=0.9.9
MYSQL_CONNECTOR_VERSION=5.1.38

# enable install of new PPAs by adding add-apt-repository capablity to apt-get
apt-get install software-properties-common -y


sudo apt-get update
sudo apt-get upgrade -y

# install apt
apt-get install apt -y

 
# DO NOT MODIFY BELOW THIS LINE.
echo "Checking system.."

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Check if this script has already been run successfully.
test -f /var/lock/guac-installed.lock && { echo "Guacamole already installed. This script cannot be run"; exit 1; }

# install lsb-release to check Distro version. Also gives us an idea if it's an apt based system!
apt  install lsb-release -y || { echo "Unsupported distribution. Aborting installation."; exit 1; }
 
# fetch the codename of the distribution (eg: trusty,wily,wheezy,jessie)
DISTVER=$(lsb_release -c | cut -d':' -f 2 | sed 's/[[:space:]]//g')
 
# Set Tomcat version depending on which distribution version else exit script
case $DISTVER in
    xenial)
        TOMCAT_VER=tomcat8
        ;;
    *)
    echo "Unsupported distribution. Sorry. Installation aborted"
    echo "Script works on Ubuntu (trusty,wily) and Debian (wheezy,jessie)"
    exit 1;
esac
 
# Set environment to non-interactive
export DEBIAN_FRONTEND="noninteractive"
 
# Today's date
TODAY=$(date +"%m-%d-%Y")
 
# get architecture - 32 bit or 64 bit
if [ $(getconf LONG_BIT | grep 64) ]; then ARCH="x86_64";  else ARCH="i386"; fi
 
# Find hostname
MYHOST=$(hostname -f)
 
#Helper functions
# Generate random string for passwords and directory names
genrand () { cat /dev/urandom | tr -dc '0-9A-Za-z+=_' | fold -w $1 | head -n 1 ; }
 
 
# Create temp directory for downloads. Uses genrand() to create random string
tmpdir=$(genrand 32)
 
cd ~
mkdir $tmpdir && cd $tmpdir
 
# Get passwords from user
clear
echo "First we need to set passwords for the CIAB Desktop system"
echo "Note: Passwords will NOT be displayed on screen!"
echo 
while true
do
    read -s -p "Enter a MySQL ROOT Password: " MYSQL_ROOT_PASSWD
    echo
    read -s -p "Please enter the MySQL ROOT Password (again): " password2
    echo
    [ "$MYSQL_ROOT_PASSWD" = "$password2" ] && break
    echo "Passwords don't match. Please try again"
done
 
echo
 
while true
do
    read -s -p "Enter a password for the Guacamole Database: " GUAC_DB_PASSWD
    echo
    read -s -p "Please enter the Guacamole Database Password (again): " password2
    echo
    [ "$GUAC_DB_PASSWD" = "$password2" ] && break
    echo "Passwords don't match. Please try again"
done
 
echo
 
while true
do
    read -s -p "Enter a password for the Guacamole (guacadmin) Web Admin account: " GUAC_ADMIN_PASSWORD
    echo
    read -s -p "Please enter the password for the Guacamole (guacadmin) Web Admin account (again): " password2
    echo
    [ "$GUAC_ADMIN_PASSWORD" = "$password2" ] && break
    echo "Passwords don't match. Please try again"
done
 
 
 
# End password input
 
 
# Upgrade all packages
apt update && apt upgrade -y
 
#Install required dependencies
echo "Installing packages"
# Tomcat version is determined by distro 
apt install $TOMCAT_VER -y
apt install $TOMCAT_VER-admin $TOMCAT_VER-docs -y

# install Ghostscript so printing will work
apt install freerdp-x11 ghostscript -y
ln -s /usr/local/lib/freerdp/* /usr/lib/$ARCH-linux-gnu/freerdp/.

apt install ntp build-essential libcairo2-dev libpng12-dev libossp-uuid-dev libjpeg-turbo8-dev libwebp-dev -y
apt install libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev libvorbis-dev -y
apt install default-jdk debconf-utils fail2ban -y
 
#MySQL install with preset password stored in variable MYSQL_ROOT_PASSWD
echo mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWD | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWD | debconf-set-selections
apt install mysql-server -y

# just in case any files failed to install lets run --fix-missing to try to correct it
apt install --fix-missing
 
# Fetch and install guacamole server and client
echo "Downloading and configuring guacamole.."

#Fetch/compile/install guacamole-server-version defined in variable GUAC_VER
wget -O guacamole-server-$GUAC_VER.tar.gz http://sourceforge.net/projects/guacamole/files/current/source/guacamole-server-$GUAC_VER.tar.gz

tar -zxvf guacamole-server-$GUAC_VER.tar.gz

cd guacamole-server-$GUAC_VER/
./configure --with-init-dir=/etc/init.d

make
make install

ldconfig

#Fetch / install client, JDBC-auth and mysql connectors 
mkdir -p /var/lib/guacamole && cd /var/lib/guacamole/
wget http://sourceforge.net/projects/guacamole/files/current/binary/guacamole-$GUAC_VER.war -O guacamole.war

ln -s /var/lib/guacamole/guacamole.war /var/lib/$TOMCAT_VER/webapps/guacamole.war

mkdir -p ~/$tmpdir/guacamole/sqlauth && cd ~/$tmpdir/guacamole/sqlauth

wget -O guacamole-auth-jdbc-$GUAC_VER.tar.gz http://sourceforge.net/projects/guacamole/files/current/extensions/guacamole-auth-jdbc-$GUAC_VER.tar.gz

tar -zxvf guacamole-auth-jdbc-$GUAC_VER.tar.gz

wget -O mysql-connector-java-$MYSQL_CONNECTOR_VERSION.tar.gz http://dev.mysql.com/get/Downloads/Connector/j/mysql-connector-java-$MYSQL_CONNECTOR_VERSION.tar.gz

tar -zxf mysql-connector-java-$MYSQL_CONNECTOR_VERSION.tar.gz

mkdir -p /usr/share/$TOMCAT_VER/.guacamole/{extensions,lib}
mv guacamole-auth-jdbc-$GUAC_VER/mysql/guacamole-auth-jdbc-mysql-$GUAC_VER.jar /usr/share/$TOMCAT_VER/.guacamole/extensions/
mv mysql-connector-java-$MYSQL_CONNECTOR_VERSION/mysql-connector-java-$MYSQL_CONNECTOR_VERSION-bin.jar /usr/share/$TOMCAT_VER/.guacamole/lib/

# restart the mysql service
service mysql restart
 
# Create Guacamole mysql user and database
mysql --host=localhost --user=root --password=$MYSQL_ROOT_PASSWD << END
 
CREATE DATABASE IF NOT EXISTS guacdb;
CREATE USER 'guacuser'@'localhost' IDENTIFIED BY '$GUAC_DB_PASSWD';
grant select,insert,update,delete on guacdb.* to 'guacuser'@'localhost';
flush privileges;
 
END
 
cd ~/$tmpdir/guacamole/sqlauth/guacamole-auth-jdbc-$GUAC_VER/mysql/schema/
cat ./*.sql | mysql --host=localhost --user=root --password=$MYSQL_ROOT_PASSWD guacdb
 
# Create guacamole.properties file
mkdir -p /etc/guacamole/ 
cat > /etc/guacamole/guacamole.properties << EOG
 
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacdb
mysql-username: guacuser
mysql-password:$GUAC_DB_PASSWD
 
mysql-disallow-duplicate-connections: false
 
EOG
 
ln -s /etc/guacamole/guacamole.properties /usr/share/$TOMCAT_VER/.guacamole/
 
# Change default guacadmin password in guacdb
mysql --host=localhost --user=root --password=$MYSQL_ROOT_PASSWD << END
 
USE guacdb;
SET @salt = UNHEX(SHA2(UUID(), 256));
UPDATE guacamole_user
SET
    password_salt = @salt,
    password_hash = UNHEX(SHA2(CONCAT('$GUAC_ADMIN_PASSWORD', HEX(@salt)), 256))
WHERE
    username = 'guacadmin';
 
END
 
#Adding patch for entropy in virtual machines
sec_file=/jre/lib/security/java.security
java_path=$(dirname $(dirname $(readlink -f $(which javac))))
if grep -xq "urandom" $java_path$sec_file ; then
  echo "File already patched to use /dev/urandom"
else
 echo  "securerandom.source=file:/dev/./urandom">> $java_path$sec_file
fi  
 
# Add links for FreeRDP depending on architecture
mkdir /usr/lib/$ARCH-linux-gnu/freerdp/
ln -s /usr/local/lib/freerdp/guac*.so /usr/lib/$ARCH-linux-gnu/freerdp/

# Adding startup services
case $DISTVER in
    xenial)
        systemctl enable $TOMCAT_VER
        systemctl enable mysql
        systemctl enable guacd
        ;;
    *)
esac
 
## Cleaning up
cd ~
rm -rf $tmpdir
 
touch /var/lock/guac-installed.lock

echo
echo
echo " Guacamole Installation is Done..."
echo
echo
echo "====================================================================================="
echo 
echo " Next you need to install NGINX!"
echo
echo " To do this, execute the following at the command prompt:"
echo
echo "        $ sudo ./setup-nginx.sh"
echo
echo "====================================================================================="
echo
echo

exit 0;
