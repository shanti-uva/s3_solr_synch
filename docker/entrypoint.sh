#!/bin/sh
echo "ENTRYPOINT!"

# Here we install all the local configs
cp -r docker/files/root/. /root


# REFACTOR to use docker secrets?
# read and export all environment variables
set -a
. /var/www/app/.env
# do env variable substitutions in these files
envsubst < /root/.aws/credentials.tmpl > /root/.aws/credentials
envsubst < /root/.config/rclone/rclone.conf.tmpl > /root/.config/rclone/rclone.conf

exec "$@"
