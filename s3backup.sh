#!/bin/sh

OPERATION="${1:-show}"
ACCESS_KEY_ID=${ACCESS_KEY_ID:?"You didn't specify your ACCESS_KEY_ID"}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY:?"You didn't specify your SECRET_ACCESS_KEY"}
S3PATH=${S3PATH:?"You didn't specify your S3PATH"}
AWSS3OPTIONS=${AWSS3OPTIONS}
AWSS3REGION=${AWSS3REGION:-us-east-1}

LOCKFILE="/var/lock/s3backup.lock"
LOGFILE="/var/log/s3backup.log"

if [ ! -e $LOGFILE ]
then
  touch $LOGFILE
fi

# Time stuff
RUN_TIME=${RUN_TIME:-28800}

if [[ $PERIOD ]] && [[ $CRON ]]
then
  echo "$(date) Both PERIOD and CRON were specified. Ignoring PERIOD." >> $LOGFILE
fi

if [[ $CRON ]]
then
  CRON=$CRON:-0 7 * * *}
  unset PERIOD
else
  PERIOD=${PERIOD:-daily}
fi

# OK, let's go...
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

    if [[ $PERIOD ]]
    then
      # We drop all the info into an executable cron file under the necessary periodic cron folder
      CRONFILE="/etc/periodic/$PERIOD/s3backup"
      echo "$(date) The backup schedule is: $PERIOD." >> $LOGFILE
      echo "$(date) Will back up the following data:" >> $LOGFILE
      echo "" >> $LOGFILE
      ls /data >> $LOGFILE
      echo "" >> $LOGFILE
      echo "$(date) Writing cron file $CRONFILE." >> $LOGFILE
      echo "#!/bin/sh" > $CRONFILE
      echo "ACCESS_KEY_ID=$ACCESS_KEY_ID" >> $CRONFILE
      echo "SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> $CRONFILE
      echo "S3PATH=$S3PATH" >> $CRONFILE
      echo "AWSS3OPTIONS=\"$AWSS3OPTIONS\"" >> $CRONFILE
      echo "/bin/sh /s3backup.sh backup" >> $CRONFILE
      chmod +x $CRONFILE
    else
      # We append the info to root's crontab file, directly
      CRONFILE="/var/spool/cron/crontabs/root"
      echo "$(date) The backup schedule is: $CRON." >> $LOGFILE
      echo "$(date) Will back up the following data:" >> $LOGFILE
      echo "" >> $LOGFILE
      ls /data >> $LOGFILE
      echo "" >> $LOGFILE
      # Populate the cron file
      echo "$(date) Writing schedule to cron file $CRONFILE." >> $LOGFILE
      echo "ACCESS_KEY_ID=$ACCESS_KEY_ID" >> $CRONFILE
      echo "SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> $CRONFILE
      echo "S3PATH=$S3PATH" >> $CRONFILE
      echo "AWSS3OPTIONS=\"$AWSS3OPTIONS\"" >> $CRONFILE
      echo "$CRON /bin/sh /s3backup.sh backup" >> $CRONFILE
    fi

    # Start the cron daemon
    echo "$(date) Starting cron daemon." >> $LOGFILE
    crond

    exec tail -F $LOGFILE
  ;;
  backup)
    echo "$(date) Beginning backup..." | tee -a $LOGFILE
    # Check for the lock file
    if [ -e $LOCKFILE ]
    then
      # Finding a lock file ends this run 
      echo "$(date) Lock file $LOCKFILE detected. Skipping this backup run." | tee -a $LOGFILE
      exit 0
    else
      # Grab start time and determine end time from run time
      START_TIME=$(date +%s)
      END_TIME=$(( $START_TIME + $RUN_TIME ))
      echo "$(date) Running backup: \"aws s3 sync /data/ $S3PATH $AWSS3OPTIONS\"" | tee -a $LOGFILE

      # Set the marker
      touch $LOCKFILE

      # Run this in the background so we can monitor and kill after run time elapses.
      aws s3 sync /data/ $S3PATH $AWSS3OPTIONS --profile=s3backup 2>&1 | tee -a $LOGFILE &

      # Loop until we either time out or the command exits
      NOW=$(date +%s)
      while [[ $NOW -le $END_TIME ]]
      do
        sleep 1
	PROCS=$(ps axw | grep -v grep | grep aws | wc -l)
	# If there aren't any running processes, we've finished
	if [[ $PROCS -lt 1 ]]
	then
	  break
	fi
	NOW=$(date +%s)
      done

      # Either we timed out or finished
      # Kill it if it's still running.
      PROCS=$(ps axw | grep -v grep | grep aws | wc -l)
      if [[ $PROCS -gt 0 ]]
      then
        killall aws
      fi

      # Clean up
      rm -f $LOCKFILE
      echo "$(date) Backup finished." | tee -a $LOGFILE
    fi
    exit 0
  ;;
  show)
    echo "Usage: s3backup.sh <operation>"
    echo "Where <operation> is one of:"
    echo "    schedule - Sets the backup schedule in crontab from environment variables"
    echo "    backup   - Starts a backup now, using established config."
    echo "    show     - Displays usage and configurations"
    echo ""
    echo "Schedule:  ${CRON}${PERIOD}"
    echo "Run time:  $RUN_TIME"
    echo "Cron file: $CRONFILE"
    echo "Log file:  $LOGFILE"
    exit 0
  ;;
esac
exit 0
