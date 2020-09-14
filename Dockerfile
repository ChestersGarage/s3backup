# Run options can be specified at container start time or interactively
#   schedule - Start-up only: Sets the schedule, starts cron and leaves
#              container running. (default)
#   backup   - Runs a backup now.
#              Start-up: Runs a backup and stops container when the backup
#              completes.
#              Interactive: Backup will run now without changing exisitng
#              schedule, then drops to a shell.
# Backup sets a lock file and checks for existing lock file before running
# a backup.

FROM alpine:3.12

RUN apk --no-cache add python3 py3-pip && \
    pip install awscli && \
    rm -rf /tmp/pip_build_root/ && \
    mkdir -p /data

ADD s3backup.sh /
RUN chmod +x /s3backup.sh && \
    ln -s /s3backup.sh /backup && \
    ln -s /s3backup.sh /show && \
    ln -s /s3backup.sh /stop && \
    echo 'export PATH=/:$PATH' >> /etc/profile

ENTRYPOINT ["/bin/sh","/s3backup.sh"]
CMD ["schedule"]
