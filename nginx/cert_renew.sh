#!/usr/bin/env bash

# Usage in crontab, running it every two months, on the first day, at 6:30 in the evening.
# 30 18 1 */2 * /root/.acme.sh/cert_renew.sh "crystal-china.org" "assets.crystal-china.org" "daka.crystal-china.org" "mail.crystal-china.org" "me.crystal-china.org" "upload.crystal-china.org"

# Need install socat before run this script for standalone mode work.

set -ue

# If apply cert for *.crystal-china.org, will need set namesilo api key.
# Then run like this
# acme.sh --issue -d crystal-china.org  -d "*.crystal-china.org" --dns dns_namesilo --dnssleep 900
export Namesilo_Key=""

if [ "$Namesilo_Key" ]; then
    dns_arg="--dns dns_namesilo"
else
    dns_arg=""
fi

acme=~/.acme.sh/acme.sh

systemctl stop nginx

# $acme --cron --home /root/.acme.sh --force --debug

domain_names=("$@")
main_domain_name="${domain_names[0]}"

args=""

for i in "${domain_names[@]}"; do
    args+=" -d $i"
done

$acme --issue --standalone --force $dns_arg $args

mkdir -p /etc/ssl/$main_domain_name

~/.acme.sh/acme.sh --installcert --ecc --force \
                   -d $main_domain_name \
                   --fullchainpath /etc/ssl/$main_domain_name/fullchain.pem \
                   --keypath /etc/ssl/$main_domain_name/privkey.pem

systemctl start nginx
