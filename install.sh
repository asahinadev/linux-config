#!/bin/sh

# メール設定
MAIL=$1
# ドメイン設定
DOMAIN=$2

RAW_URL=https://raw.githubusercontent.com/asahinadev/linux-config/main

if [ "$1" = "" ]; then
  echo "Usage $0 MAIL DOMAIN" >&2
  echo "MIAL は必須です。" >&2
  exit 1
fi

if [ "$2" = "" ]; then
  echo "Usage $0 MAIL DOMAIN" >&2
  echo "DOMAIN は必須です。" >&2
  exit 1
fi

#########################
# 最新化（kernelは除外）#
#########################
yum -y update  -x kernel*

#######################################
# Extra Packages for Enterprise Linux #
#######################################
yum -y install epel-release

#####################################
# yum config manager インストール   #
#####################################
yum -y install yum-utils

########################
# php-fpm インストール #
########################
yum -y install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php74
yum -y install \
  php-fpm      \
  php-mbstring \
  php-intl     \
  php-xml      \
  php-mysql    \
  php-pdo      

########################
# nginx インストール   #
########################
yum -y remove  httpd
yum -y install nginx

########################
# docker インストール  #
########################
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install          \
  docker-ce             \
  docker-ce-cli         \
  docker-compose.noarch  

########################
# postfix インストール #
########################
yum -y install \
  certbot \
  python2-certbot-nginx \
  postfix \
  dovecot \
  cyrus-sasl \
  cyrus-sasl-md5 \
  cyrus-sasl-plain

#################
# nginx 設定    #
#################
systemctl enable nginx
systemctl start nginx

firewall-cmd --reload
firewall-cmd --list-all --permanent

cd /etc/nginx/
cp -a nginx.conf nginx.conf.org
curl -O $RAW_URL/etc/nginx/nginx.conf

cd conf.d
curl \
 -O $RAW_URL/etc/nginx/conf.d/00.default.server.conf \
 -O $RAW_URL/etc/nginx/conf.d/01.www.server.conf
sed -i "s/__DOMAIN__/$DOMAIN/g" 00.default.server.conf
sed -i "s/__DOMAIN__/$DOMAIN/g" 01.www.server.conf

certbot certonly \
    --nginx                     \
    --agree-tos                 \
    --non-interactive           \
    --keep                      \
    --expand                    \
    -d $DOMAIN                  \
    -d www.$DOMAIN              \
    -d test.$DOMAIN             \
    -d gitlab.$DOMAIN           \
    -d mail.$DOMAIN             \
    --email $MAIL

cd /etc/postfix/
cp -a main.cf   main.cf.org
cp -a master.cf master.cf.org
curl \
 -O $RAW_URL/etc/postfix/main.cf \
 -O $RAW_URL/etc/postfix/master.cf

# ドメイン調整
sed -i "s/__DOMAIN__/$DOMAIN/g" main.cf
cat main.cf | grep $DOMAIN

cd /etc/dovecot
cp -a dovecot.conf dovecot.conf.org

curl -O $RAW_URL/etc/dovecot/dovecot.conf

cd conf.d
cp -a 10-master.conf 10-master.conf.org
cp -a 10-ssl.conf    10-ssl.conf.org
cp -a 10-auth.conf   10-auth.conf.org
cp -a 10-mail.conf   10-mail.conf.org

curl \
 -O $RAW_URL/etc/dovecot/conf.d/10-auth.conf \
 -O $RAW_URL/etc/dovecot/conf.d/10-mail.conf \
 -O $RAW_URL/etc/dovecot/conf.d/10-master.conf \
 -O $RAW_URL/etc/dovecot/conf.d/10-ssl.conf
sed -i "s/__DOMAIN__/$DOMAIN/g" 10-ssl.conf
cat 10-ssl.conf | grep $DOMAIN

systemctl enable postfix dovecot

#################
# firewall 設定 #
#################
firewall-cmd --permanent \
    --add-service=http   \
    --add-service=https  \
    --add-service=imaps  \
    --add-service=smtps  


#################
# サービス起動  #
#################
systemctl restart nginx
systemctl start  postfix dovecot
