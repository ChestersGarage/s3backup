# s3backup

S3backup is a small and light-weight Docker container based on Alpine Linux
that backups up specified folders to an AWS S3 bucket.

## Usage

### Volumes
Mount your data folders as volumes under the `/data` directory.

It may also be beneficial to mount the container's `/var/log` directory outside
of the container so that you can keep that information when removing and
re-running the container.

### Environment Variables
You must provide the following environment variables when you run the
container:
- ACCESS_KEY_ID     - Your AWS IAM Access Key ID
- SECRET_ACCESS_KEY - Your AWS IAM Secret Access Key
- S3PATH            - Your S3 bucket and path
- AWSS3OPTIONS      - Custom parameters for "aws s3 sync ..."

You may provide the following optional variables as well:
- PERIOD - Sets the backup schedule (see below)

#### Scheduler Options
You may specify one of the following backup schedules:
(I'm still trying to find out what day and time of day the longer periods run.)
- 15min   - Runs a backup every 15 minutes.
- hourly  - Runs a backup every hour on the hour.
- daily   - Runs a backup every day.
- weekly  - Runs a backup every week.
- monthly - Runs a backup every month.

The default backup schedule is "hourly".

## Examples

To back up your `Music` and `Photos` folders in your home directory once per day:

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

To back up the Media directory on your unRAID server once per week, keep a
persistent backup log in /var/log/s3backup.log, and use reduced redundancy
S3 storage to save a few pennies:

```
docker run -d \
-v /mnt/user/Media:/data/Media:ro \
-v /var/log/s3backup.log:/var/log/s3backup.log:rw \
-e "ACCESS_KEY_ID=<youraccesskeyid>" \
-e "SECRET_ACCESS_KEY=<yoursecretaccesskey>" \
-e "S3PATH=s3://<yours3bucket>/<youroptionalfolder>/" \
-e "PERIOD=weekly" \
-e "AWSS3OPTIONS=--storage-class REDUCED_REDUNDANCY" \
--name s3backup \
chestersgarage/s3backup
```
