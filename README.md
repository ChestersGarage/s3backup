# s3backup

S3backup is a small and light-weight Docker image based on the Alpine Linux official image (alpine:latest) that backs up specified folders to an AWS S3 bucket, on a periodic or cron schedule.

## Volumes

Mount the folders you wish to back up as volumes under the container's `/data` directory.

It may also be beneficial to mount the container's `/var/log` directory outside of the container so that you can keep that information when removing and re-running the container.

## Environment Variables

You must provide the following environment variables when you run the container:
- ACCESS_KEY_ID     - Your AWS IAM Access Key ID
- SECRET_ACCESS_KEY - Your AWS IAM Secret Access Key
- S3PATH            - Your S3 bucket and path

You may provide the following optional variables as well:
- CRON_PATTERN - Sets the backup on an explicit cron schedule (see below)
- PERIOD       - Sets the backup on a periodic schedule (see below)
- AWSS3REGION  - Defaults to "us-east-1"
- AWSS3OPTIONS - Custom parameters for "aws s3 sync ..."

#### Scheduler Options

There are two ways to schedule when your backups start:
- Periodically (PERIOD)
- Cron Schedule (CRON_PATTERN)

You can also set the run time (RUN_TIME) to limit how long the backup can run.

Specify only one of PERIOD or CRON_PATTERN when starting your container. If both are specified, PERIOD will be ignored.

##### Period

You may specify one of the following backup PERIODs:
- PERIOD=15min   - Runs a backup every 15 minutes
- PERIOD=hourly  - Runs a backup every hour on the hour
- PERIOD=daily   - Runs a backup every day @ 02:00 GMT
- PERIOD=weekly  - Runs a backup every week on Saturday @ 03:00 GMT
- PERIOD=monthly - Runs a backup every month on the 1st @ 05:00 GMT

**If left unspecified, the default is a cron schedule below.**

##### Cron

You can pass in a custom cron schedule pattern for more granular control of your start times.
- E.g.: "Every Saturday at 5:02 AM GMT" -> CRON_PATTERN=05 02 * * 6

The time and date fields are:
-       minute         0-59
-       hour           0-23
-       day of month   1-31
-       month          1-12
-       day of week    0-7 (0 or 7 is Sunday)

**If left unspecified, the default is daily at 07:00 GMT.** (`"CRON_PATTERN=0 7 * * *"`)

##### Run Time limit

You can specify how long the backup job will run before being stopped. 
- RUN_TIME=<number_of_seconds>

**If left unspecified, the default run time is 28800 seconds (8 hours).**

## Examples

- To back up your `Music` and `Photos` folders in your home directory once per day @ 02:00 GMT:

```
docker run -d \
-v /home/user/Music:/data/Music:ro \
-v /home/user/Photos:/data/Photos:ro \
-e "ACCESS_KEY_ID=<youraccesskeyid>" \
-e "SECRET_ACCESS_KEY=<yoursecretaccesskey>" \
-e "S3PATH=s3://<yours3bucket>/<youroptionalfolder>/" \
-e "PERIOD=daily" \
--name s3backup \
chestersgarage/s3backup
```

- To back up the Media directory on your unRAID server daily from 23:00-05:00 Pacific time (06:00-12:00 GMT) ONLY, keep a persistent backup log in /mnt/cache/appdata/s3backup/logs, and use reduced redundancy S3 storage to save a few pennies:

```
docker run -d \
-v /mnt/user/Media:/data/Media:ro \
-v /mnt/cache/appdata/s3backup/logs:/var/log:rw \
-e "ACCESS_KEY_ID=<youraccesskeyid>" \
-e "SECRET_ACCESS_KEY=<yoursecretaccesskey>" \
-e "S3PATH=s3://<yours3bucket>/<youroptionalfolder>/" \
-e "CRON_PATTERN=0 6 * * *" \
-e "RUN_TIME=21600" \
-e "AWSS3OPTIONS=--storage-class REDUCED_REDUNDANCY" \
--name s3backup \
chestersgarage/s3backup
```
## Interacting

- Connect to the container to run a manual backup:

```
docker exec -it s3backup backup
```

- Connect to the container to view current configuration:

```
docker exec -it s3backup show
```

- Connect to the container just to poke aroud:

```
docker exec -it s3backup /bin/sh
```

## Useful Options

- The default configuration does not delete files in the S3 bucket. It only overwrites and adds files. If you'd like a more lean sync, you can add the option to delete files from S3 that no longer exist on your source:

```
-e "AWSS3OPTIONS=--delete"
```

## More Information

- AWS CLI docs for "aws s3 sync ..."
  - http://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
- AWS S3 pricing:
  - https://aws.amazon.com/s3/pricing/
  - https://aws.amazon.com/s3/reduced-redundancy/

