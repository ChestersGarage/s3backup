#!/bin/sh

OPERATION="${1:-show}"
ACCESS_KEY_ID=${ACCESS_KEY_ID:?"You didn't specify your ACCESS_KEY_ID"}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY:?"You didn't specify your SECRET_ACCESS_KEY"}
S3PATH=${S3PATH:?"You didn't specify your S3PATH"}
AWSS3OPTIONS=${AWSS3OPTIONS}
AWSS3REGION=${AWSS3REGION:-us-east-1}

LOCKFILE="/var/lock/s3backup.lock"
LOGFILE="/var/log/s3backup.log"

if [ ! -e ${LOGFILE} ]
then
  touch ${LOGFILE}
fi

# Write-to-log
wtlog(){
  echo "$(date) $1: $2" >> ${LOGFILE}
}

# Time stuff
RUN_TIME=${RUN_TIME:-28800}

if [[ "${PERIOD}" ]] && [[ "${CRON_PATTERN}" ]]
then
  wtlog WARN "Both PERIOD and CRON_PATTERN were specified. Ignoring PERIOD."
fi

# Check for empty cron pattern
if [[ -z "${CRON_PATTERN}" ]]
then
  # Set PERIOD to daily if not provided
  PERIOD=${PERIOD:-daily}
else
  # We can't have both set
  CRON_PATTERN="${CRON_PATTERN:-0 7 * * *}"
  PERIOD=""
  unset PERIOD
fi

# OK, let's go
case ${OPERATION} in
  schedule)
    if [[ -f ${LOCKFILE} ]]
    then
      rm -f ${LOCKFILE}
      killall aws
    fi

    wtlog INFO "Establishing AWS account settings."
    mkdir -p /root/.aws
    cat > /root/.aws/config <<EOF
[profile s3backup]
output = table
region = ${AWSS3REGION}
EOF
    cat > /root/.aws/credentials <<EOF
[s3backup]
aws_access_key_id = ${ACCESS_KEY_ID}
aws_secret_access_key = ${SECRET_ACCESS_KEY}
EOF
    chmod -R go-rwx /root/.aws

    if [[ ${PERIOD} ]]
    then
      # We drop all the info into an executable cron file under the necessary periodic cron folder
      CRONFILE="/etc/periodic/${PERIOD}/s3backup"
      wtlog INFO "The backup schedule is: ${PERIOD}."
      wtlog INFO "Will back up the following data:"
      FOLDERS=$(ls --color=never /data)
      for folder in ${FOLDERS}; do wtlog INFO ${folder}; done
      wtlog INFO "Writing cron file ${CRONFILE}."
      cat > $CRONFILE <<EOF
#!/bin/sh
ACCESS_KEY_ID=${ACCESS_KEY_ID}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
S3PATH="${S3PATH}"
AWSS3OPTIONS="${AWSS3OPTIONS}"
/bin/sh /s3backup.sh backup
EOF
      chmod +x ${CRONFILE}
      cat > /etc/crontabs/root <<EOF
# Make sure the periodic schedules are clean
# min   hour    day     month   weekday command
*/15    *       *       *       *       run-parts /etc/periodic/15min
0       *       *       *       *       run-parts /etc/periodic/hourly
0       2       *       *       *       run-parts /etc/periodic/daily
0       3       *       *       6       run-parts /etc/periodic/weekly
0       5       1       *       *       run-parts /etc/periodic/monthly
EOF
    else
      # We append the info to root's crontab file, directly
      CRONFILE="/etc/crontabs/root"
      wtlog INFO "The backup schedule is: ${CRON_PATTERN}."
      wtlog INFO "Will back up the following data:"
      FOLDERS=$(ls --color=never /data)
      for folder in ${FOLDERS}; do wtlog INFO ${folder}; done
      # Populate the cron file
      wtlog INFO "Writing schedule to cron file ${CRONFILE}."
      cat > $CRONFILE <<EOF
#!/bin/sh
ACCESS_KEY_ID=${ACCESS_KEY_ID}
SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
S3PATH="${S3PATH}"
AWSS3OPTIONS="${AWSS3OPTIONS}"
${CRON_PATTERN} /bin/sh /s3backup.sh backup
EOF
    fi

    # Start the cron daemon
    wtlog INFO "Starting cron daemon."
    crond

    exec tail -Fn 25 ${LOGFILE}
  ;;
  backup)
    wtlog INFO "Beginning backup..."
    # Check for the lock file
    if [ -e ${LOCKFILE} ]
    then
      # Finding a lock file ends this run
      wtlog WARN "Lock file ${LOCKFILE} detected. Skipping this backup run."
      exit 0
    else
      # Grab start time and determine end time from run time
      START_TIME=$(date +%s)
      END_TIME=$(( ${START_TIME} + ${RUN_TIME} ))

      # Set the marker
      touch ${LOCKFILE}

      # Run this in the background so we can monitor and kill after run time elapses.
      COMMAND="aws s3 sync --quiet /data/ ${S3PATH} ${AWSS3OPTIONS} --profile=s3backup"
      wtlog INFO "Running backup: \"${COMMAND}\""
      ${COMMAND} 2>&1 | tee -a ${LOGFILE} &

      # Loop until we either time out or the command exits
      NOW=$(date +%s)
      while [[ ${NOW} -le ${END_TIME} ]]
      do
        sleep 1
	PROCS=$(ps axw | grep -v grep | grep aws | wc -l)
	# If there aren't any running processes, we've finished
	if [[ ${PROCS} -lt 1 ]]
	then
	  break
	fi
	NOW=$(date +%s)
      done

      # Either we timed out or finished
      # Kill it if it's still running.
      PROCS=$(ps axw | grep -v grep | grep aws | wc -l)
      if [[ ${PROCS} -gt 0 ]]
      then
        killall aws
      fi

      # Clean up
      rm -f ${LOCKFILE}
      wtlog INFO "Backup finished."
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
    echo "Schedule: ${CRON_PATTERN}${PERIOD}"
    echo "Run time: ${RUN_TIME}"
    echo "Current time: $(date) (Cron pattern: $(date '+%M %H %d %m %u'))"
    echo "Log file: ${LOGFILE}"
    echo "Data folders: $(ls /data)"
    exit 0
  ;;
  stop)
    killall aws
    wtlog WARN "Forced stop by command."
esac
exit 0
