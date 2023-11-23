FROM alpine:3.13.2 AS builder

# Install all dependencies required for compiling busybox and also libcap
RUN apk add gcc musl-dev make perl libcap

# Download busybox sources
RUN wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2 \
  && tar xf busybox-1.35.0.tar.bz2 \
  && mv /busybox-1.35.0 /busybox

WORKDIR /busybox

# Copy the busybox build config (limited to httpd)
COPY .config .

# Compile and install busybox
RUN make && make install

# Allow the httpd process to bind to port 8080 without running as root
# RUN setcap 'cap_net_bind_service=+ep' /busybox/_install/bin/busybox/

# Create a non-root user to own the files and run our server
RUN adduser -D static

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

# Use our non-root user
USER static
WORKDIR /home/static

# Uploads a httpd.conf
COPY httpd.conf .

# Copy the static website
# Use the .dockerignore file to control what ends up inside the image!
COPY . .

# Run busybox httpd
CMD ["/busybox", "httpd", "-f", "-v", "-p", "8080", "-c", "httpd.conf"]