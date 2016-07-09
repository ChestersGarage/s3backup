# s3backup

S3backup is a small and light-weight Docker image based on the Alpine Linux official image (alpine:latest) that periodically backups up specified folders to an AWS S3 bucket.

## Volumes

Mount your data folders as volumes under the `/data` directory.

It may also be beneficial to mount the container's `/var/log` directory outside of the container so that you can keep that information when removing and re-running the container.

## Environment Variables

You must provide the following environment variables when you run the container:
- ACCESS_KEY_ID     - Your AWS IAM Access Key ID
- SECRET_ACCESS_KEY - Your AWS IAM Secret Access Key
- S3PATH            - Your S3 bucket and path

You may provide the following optional variables as well:
- PERIOD       - Sets the backup schedule (see below)
- AWSS3REGION  - Defaults to "us-east-1"
- AWSS3OPTIONS - Custom parameters for "aws s3 sync ..."

#### Scheduler Options

You may specify one of the following backup schedules:
(I'm still trying to find out what day and time of day the longer periods run.)
- 15min   - Runs a backup every 15 minutes
- hourly  - Runs a backup every hour on the hour
- daily   - Runs a backup every day
- weekly  - Runs a backup every week
- monthly - Runs a backup every month

**If left unspecified, the default backup schedule is "hourly".**

## Examples

- To back up your `Music` and `Photos` folders in your home directory once per day:

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

- To back up the Media directory on your unRAID server once per week, keep a persistent backup log in /mnt/cache/appdata/s3backup/logs, and use reduced redundancy S3 storage to save a few pennies:

```
docker run -d \
-v /mnt/user/Media:/data/Media:ro \
-v /mnt/cache/appdata/s3backup/logs:/var/log:rw \
-e "ACCESS_KEY_ID=<youraccesskeyid>" \
-e "SECRET_ACCESS_KEY=<yoursecretaccesskey>" \
-e "S3PATH=s3://<yours3bucket>/<youroptionalfolder>/" \
-e "PERIOD=weekly" \
-e "AWSS3OPTIONS=--storage-class REDUCED_REDUNDANCY" \
--name s3backup \
chestersgarage/s3backup
```
## Interacting

- Connect to the container to run a manual backup:

```
docker exec -it s3backup backup
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
-- http://docs.aws.amazon.com/cli/latest/reference/s3/sync.html
- AWS S3 pricing:
-- https://aws.amazon.com/s3/pricing/
-- https://aws.amazon.com/s3/reduced-redundancy/

