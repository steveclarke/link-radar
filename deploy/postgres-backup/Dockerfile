FROM postgres:18-alpine

# Install s3cmd and dcron for backups
RUN apk add --no-cache \
    s3cmd \
    dcron \
    bash \
    gzip

# Copy backup script and s3 config template
COPY backup.sh /backup.sh
COPY .s3cfg.template /root/.s3cfg.template
RUN chmod +x /backup.sh

# Setup cron - every 3 hours
RUN echo "0 */3 * * * /backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# Create log file
RUN touch /var/log/cron.log

# Start cron in foreground
CMD crond -f -l 2

