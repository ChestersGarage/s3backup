#!/bin/sh

OPERATION="$1"
ACCESS_KEY_ID=${ACCESS_KEY_ID:?"You didn't specify your ACCESS_KEY_ID"}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY:?"You didn't specify your SECRET_ACCESS_KEY"}
S3PATH=${S3PATH:?"You didn't specify your S3PATH"}
PERIOD=${PERIOD:-hourly}
AWSS3OPTIONS=${AWSS3OPTIONS}
AWSS3REGION=${AWSS3REGION:-us-east-1}

LOCKFILE="/var/lock/s3backup.lock"
LOGFILE="/var/log/s3backup.log"

if [ ! -e $LOGFILE ]
then
  touch $LOGFILE
fi

case $OPERATION in
  schedule)
    if [[ -f $LOCKFILE ]]
    then
      rm -f $LOCKFILE
      killall aws
    fi

    echo "$(date) Establishing AWS account settings." >> $LOGFILE
    mkdir -p /root/.aws
    echo -e "[profile s3backup]\noutput = table\nregion = ${AWSS3REGION}" > /root/.aws/config
    echo -e "[s3backup]\naws_access_key_id = ${ACCESS_KEY_ID}\naws_secret_access_key = ${SECRET_ACCESS_KEY}" > /root/.aws/credentials
    chmod -R go-rwx /root/.aws

    CRONFILE="/etc/periodic/$PERIOD/s3backup"
  
    echo "$(date) The backup schedule is: $PERIOD." >> $LOGFILE
    echo "$(date) Will back up the following data:" >> $LOGFILE
    echo "" >> $LOGFILE
    ls /data >> $LOGFILE
    echo "" >> $LOGFILE
    # Populate the cron file
    echo "$(date) Writing cron file $CRONFILE." >> $LOGFILE
    echo "#!/bin/sh" > $CRONFILE
    echo "ACCESS_KEY_ID=$ACCESS_KEY_ID" >> $CRONFILE
    echo "SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> $CRONFILE
    echo "S3PATH=$S3PATH" >> $CRONFILE
    echo "AWSS3OPTIONS=\"$AWSS3OPTIONS\"" >> $CRONFILE
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
      echo "$(date) Running backup: \"aws s3 sync /data/ $S3PATH $AWSS3OPTIONS\"" | tee -a $LOGFILE
      touch $LOCKFILE
      aws s3 sync /data/ $S3PATH $AWSS3OPTIONS --profile=s3backup 2>&1 | tee -a $LOGFILE
      rm -f $LOCKFILE
      echo "$(date) Backup finished." | tee -a $LOGFILE
    fi
  ;;
esac

