FROM node:18-bullseye
WORKDIR '/var/www/app'
COPY package.json .
COPY package-lock.json .
RUN npm ci
RUN chown node:node /var/www/app
RUN chmod 1777 /tmp
RUN apt-get -y update && \
   apt-get -y install --no-install-recommends --fix-missing vim less && \
   apt-get -y install --no-install-recommends --fix-missing clsync && \
   apt-get -y install --no-install-recommends --fix-missing rclone && \
   apt-get -y install --no-install-recommends --fix-missing gettext-base && \
   apt-get -y install --no-install-recommends --fix-missing psmisc && \
   rm -rf /var/lib/apt/lists/*
COPY . .
#COPY files/root/.config/rclone/rclone.conf /root/.config/rclone/rclone.conf
#COPY files/root/.aws/credentials /root/.aws/credentials
#
#COPY files/root/.config/rclone/rclone.conf /home/node/.config/rclone/rclone.conf
#COPY files/root/.aws/credentials /home/node/.aws/credentials
#RUN chown -R node:node /home/node/.aws /home/node/.config/rclone /home/node/.rclone.conf
#
COPY docker/files/usr/local/bin/synchandler.pl /usr/local/bin/synchandler.pl
RUN chmod 775 /usr/local/bin/synchandler.pl

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/test test

RUN chmod +x /usr/local/bin/entrypoint.sh

RUN npm install --production

USER root
ENTRYPOINT [ "/bin/sh","/usr/local/bin/entrypoint.sh" ]
CMD [ "node", "src/synch.js" ]
