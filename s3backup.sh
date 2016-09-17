#!/bin/sh

OPERATION="$1"
ACCESS_KEY=${ACCESS_KEY:?"You didn't specify your ACCESS_KEY"}
SECRET_KEY=${SECRET_KEY:?"You didn't specify your SECRET_KEY"}
S3PATH=${S3PATH:?"You didn't specify your S3PATH"}
PERIOD=${PERIOD:-hourly}
AWSCLIPARAMS=${AWSCLIPARAMS}
AWS_S3_REGION=${AWS_S3_REGION:-us-east-1}

LOCKFILE="/var/lock/s3backup.lock"
LOGFILE="/var/log/s3backup.log"

if [ ! -e $LOGFILE ]
then
  touch $LOGFILE
fi

case $OPERATION in
  schedule)
    echo "$(date) Establishing AWS account settings." >> $LOGFILE
    echo -e "[profile s3backup]\noutput = table\nregion = ${AWS_S3_REGION}" > /root/.aws/config
    echo -e "[s3backup]\naws_access_key_id = ${ACCESS_KEY}\naws_secret_access_key = ${SECRET_KEY}" > /root/.aws/credentials
    chmod -R go-rwx /root/.aws

    CRONFILE="/etc/periodic/$PERIOD/s3backup"
  
    echo "$(date) The backup schedule is: $PERIOD." >> $LOGFILE
    echo -n "$(date) Will back up the following data:" >> $LOGFILE
    ls /data >> $LOGFILE
    # Populate the cron file
    echo "$(date) Writing cron file $CRONFILE." >> $LOGFILE
    echo "#!/bin/sh" > $CRONFILE
    echo "ACCESS_KEY=$ACCESS_KEY" >> $CRONFILE
    echo "SECRET_KEY=$SECRET_KEY" >> $CRONFILE
    echo "S3PATH=$S3PATH" >> $CRONFILE
    echo "AWSCLIPARAMS=\"$AWSCLIPARAMS\"" >> $CRONFILE
    echo "/bin/sh /s3backup.sh backup" >> $CRONFILE
    chmod +x $CRONFILE

    # Start the cron daemon
    echo "$(date) Starting cron daemon." >> $LOGFILE
    crond

    exec tail -F $LOGFILE
  ;;
  backup)
    echo "$(date) Beginning backup..." | tee -a $LOGFILE
    if [ -e $LOCKFILE ]
    then
      echo "$(date) Lock file $LOCKFILE detected. Skipping this backup run." | tee -a $LOGFILE
    else
      echo "$(date) Running backup: \"aws s3 sync /data/ $S3PATH $AWSCLIPARAMS\"" | tee -a $LOGFILE
      touch $LOCKFILE
      aws s3 sync /data/ $S3PATH $AWSCLIPARAMS --profile=s3backup 2>&1 | tee -a $LOGFILE
      rm -f $LOCKFILE
      echo "$(date) Backup finished." | tee -a $LOGFILE
    fi
  ;;
esac
