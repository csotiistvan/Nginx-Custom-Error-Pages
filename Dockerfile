FROM alpine:3.13.2 AS builder

# Install all dependencies required for compiling busybox
RUN apk add gcc musl-dev make perl authbind

# Download busybox sources
RUN wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2 \
  && tar xf busybox-1.35.0.tar.bz2 \
  && mv /busybox-1.35.0 /busybox

WORKDIR /busybox

# Copy the busybox build config (limited to httpd)
COPY .config .

# Compile and install busybox
RUN make && make install

# Create a non-root user to own the files and run our server
RUN adduser -D static

# Create a file /etc/authbind/byport/8080 and set its permissions to allow the httpd process to bind to port 8080
RUN touch /etc/authbind/byport/8080
RUN chmod 777 /etc/authbind/byport/8080

# Switch to the scratch image
FROM scratch

LABEL \
    # Docs: <https://github.com/opencontainers/image-spec/blob/master/annotations.md>
    org.opencontainers.image.title="custom-errors" \
    org.opencontainers.image.description="Static server error pages in the docker image" \
    org.opencontainers.image.url="https://github.com/csotiistvan/Nginx-Custom-Error-Pages/" \
    org.opencontainers.image.source="https://github.com/csotiistvan/Nginx-Custom-Error-Pages/" \
    org.opencontainers.image.vendor="WHO"

EXPOSE 8080

# Copy over the user
COPY --from=builder /etc/passwd /etc/passwd

# Copy the busybox static binary
COPY --from=builder /busybox/_install/bin/busybox /

# Copy over authbind bin and config
COPY --from=builder /etc/authbind/byport/8080 /etc/authbind/byport/8080
COPY --from=builder /usr/sbin/authbind /usr/sbin/authbind

# Use our non-root user
USER static
WORKDIR /home/static

# Uploads a blank default httpd.conf
# This is only needed in order to set the `-c` argument in this base file
# and save the developer the need to override the CMD line in case they ever
# want to use a httpd.conf
COPY httpd.conf .

# Copy the static website
# Use the .dockerignore file to control what ends up inside the image!
COPY . .

# Run busybox httpd
CMD ["authbind", "--deep", "/busybox", "httpd", "-f", "-v", "-p", "8080", "-c", "httpd.conf"]