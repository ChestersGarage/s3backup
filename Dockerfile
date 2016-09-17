# Run options can be specified at container start time or interactively
#   schedule - Start-up only: Sets the schedule, starts cron and leaves container running. (default)
#   backup   - Runs a backup now. 
#              Start-up: Runs a backup and stops container when the backup completes.
#              Interactive: Backup will run now without changing exisitng schedule, then drops to a shell. (default)
# Backup sets a lock file and checks for existing lock file before running a backup.
 
FROM alpine:latest

MAINTAINER Mark Chester <mark@chestersgarage.com>

RUN apk --no-cache add python py-pip
RUN pip install awscli
RUN rm -rf /tmp/pip_build_root/

RUN mkdir -p /data
RUN mkdir -p /root/.aws
RUN echo -e "[profile s3backup]\noutput = table\nregion = ${AWS_S3_REGION:-us-east-1}" >> /root/.aws/config
RUN echo -e "[s3backup]\naws_access_key_id = ${ACCESS_KEY_ID}\naws_secret_access_key = ${SECRET_ACCESS_KEY}" >> /root/.aws/credentials
RUN chmod -R go-rwx /root/.aws

ADD s3backup.sh /

ENTRYPOINT ["/bin/sh","/s3backup.sh"]
CMD ["schedule"]
