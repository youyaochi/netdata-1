#!/bin/bash

# fix permissions due to netdata running as root
chown root:root /usr/share/netdata/web/ -R
echo -n "" > /usr/share/netdata/web/version.txt

# set up ssmtp
if [[ $SSMTP_TO ]] && [[ $SSMTP_USER ]] && [[ $SSMTP_PASS ]]; then
cat << EOF > /etc/ssmtp/ssmtp.conf
root=$SSMTP_TO
mailhub=$SSMTP_SERVER:$SSMTP_PORT
AuthUser=$SSMTP_USER
AuthPass=$SSMTP_PASS
UseSTARTTLS=$SSMTP_TLS
hostname=$SSMTP_HOSTNAME
FromLineOverride=NO
EOF

cat << EOF > /etc/ssmtp/revaliases
netdata:netdata@$SSMTP_HOSTNAME:$SSMTP_SERVER:$SSMTP_PORT
root:netdata@$SSMTP_HOSTNAME:$SSMTP_SERVER:$SSMTP_PORT
EOF
fi

if [[ $SLACK_WEBHOOK_URL ]]; then
  sed -i -e "s@SLACK_WEBHOOK_URL=\"\"@SLACK_WEBHOOK_URL=\"${SLACK_WEBHOOK_URL}\"@" /etc/netdata/health_alarm_notify.conf
fi

if [[ $SLACK_CHANNEL ]]; then
  sed -i -e "s@DEFAULT_RECIPIENT_SLACK=\"\"@DEFAULT_RECIPIENT_SLACK=\"${SLACK_CHANNEL}\"@" /etc/netdata/health_alarm_notify.conf
fi

# exec custom command
if [[ $# -gt 0 ]] ; then
        exec "$@"
        exit
fi

if [[ -d "/fakenet/" ]]; then
	echo "Running fakenet config reload in background"
	( sleep 10 ; curl -s http://localhost:${NETDATA_PORT}/netdata.conf | sed -e 's/# filename/filename/g' | sed -e 's/\/host\/proc\/net/\/fakenet\/proc\/net/g' > /etc/netdata/netdata.conf ; pkill -9 netdata ) &
	/usr/sbin/netdata -D -u root -s /host -p ${NETDATA_PORT}
	# add some artificial sleep because netdata might think it can't bind to $NETDATA_PORT
	# and report things like "netdata: FATAL: Cannot listen on any socket. Exiting..."
	sleep 1
fi

# main entrypoint
exec /usr/sbin/netdata -D -u root -s /host -p ${NETDATA_PORT}