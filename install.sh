#!/bin/sh

# メール設定
MAIL=$1
# ドメイン設定
DOMAIN=$2

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

yum -y install epel-release
yum -y install \
  nginx certbot \
  python2-certbot-nginx \
  postfix \
  dovecot \
  cyrus-sasl \
  cyrus-sasl-md5 \
  cyrus-sasl-plain


#################
# firewall 設定 #
#################
firewall-cmd --permanent \
    --add-service=http   \
    --add-service=https  \
    --add-service=imaps  \
    --add-service=smtps  \
    --add-service=imap   \
    --add-service=smtp   \

#################
# nginx 設定    #
#################
systemctl enable nginx
systemctl start nginx

firewall-cmd --reload
firewall-cmd --list-all --permanent

cd /etc/nginx/
cp -a nginx.conf nginx.conf.org
curl -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/nginx/nginx.conf

cd conf.d
curl \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/nginx/cd%20conf.d/00.default.server.conf \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/nginx/cd%20conf.d/01.www.server.conf
sed -i "s/__DOMAIN__/$DOMAIN/g" 00.default.server.conf
sed -i "s/__DOMAIN__/$DOMAIN/g" 01.www.server.conf



certbot certonly \
    --nginx                     \
    --agree-tos                 \
    --non-interactive           \
    --keep                      \
    --expand                    \
    -d mirror-world.work        \
    -d www.mirror-world.work    \
    -d test.mirror-world.work   \
    -d gitlab.mirror-world.work \
    -d mail.mirror-world.work   \
    --email $MAIL \
  2>&1 | tee -a  $LOG.stdout

cd /etc/postfix/
cp -a main.cf   main.cf.org
cp -a master.cf master.cf.org
curl \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/postfix/main.cf \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/postfix/master.cf
# ドメイン調整
sed -i "s/__DOMAIN__/$DOMAIN/g" main.cf
cat main.cf | grep $DOMAIN

cd /etc/dovecot
cp -a dovecot.conf dovecot.conf.org
curl -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/dovecot/dovecot.conf

cd conf.d
cp -a 10-master.conf 10-master.conf.org
cp -a 10-ssl.conf    10-ssl.conf.org
cp -a 10-auth.conf   10-auth.conf.org
cp -a 10-mail.conf 10-mail.conf.org
curl \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/dovecot/conf.d/10-auth.conf \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/dovecot/conf.d/10-mail.conf \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/dovecot/conf.d/10-master.conf \
 -O https://raw.githubusercontent.com/asahinadev/linux-config/main/etc/dovecot/conf.d/10-ssl.conf
sed -i "s/__DOMAIN__/mirror-world.work/g" 10-ssl.conf
cat 10-ssl.conf | grep $DOMAIN
