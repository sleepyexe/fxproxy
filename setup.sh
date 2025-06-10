#!/bin/bash

echo "Setting up Nginx Caching Proxy on Ubuntu..."

# Create project directory
mkdir -p nginx-proxy
cd nginx-proxy

# Create cache directory
mkdir -p cache logs

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Create cache directory
RUN mkdir -p /srv/cache && \
    chown -R nginx:nginx /srv/cache

# Copy nginx configuration template
COPY default.template /etc/nginx/conf.d/default.template

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose port
EXPOSE 3128

# Start nginx with environment variable substitution
CMD ["/start.sh"]
EOF

# Create nginx config template
cat > default.template << 'EOF'
proxy_cache_path /srv/cache levels=1:2 keys_zone=assets:48m max_size=10g ;

log_format asset '$remote_addr - [$time_local] "$request" $status $body_bytes_sent $upstream_cache_status';

server {
    listen 80;
    location /files/ {
        access_log /dev/stdout asset;
        add_header X-Cache-Status $upstream_cache_status;
        proxy_cache_lock on;
        proxy_pass $REMOTE$request_uri;
        proxy_cache assets;
        proxy_cache_valid 1y;
        proxy_cache_key $request_uri$is_args$args;
    }
}
EOF

# Create startup script
cat > start.sh << 'EOF'
#!/bin/sh

# Check if REMOTE environment variable is set
if [ -z "$REMOTE" ]; then
    echo "ERROR: REMOTE environment variable is not set"
    echo "Please set REMOTE to the upstream server URL (e.g., http://10.10.0.2:30120)"
    exit 1
fi

# Get all environment variables for substitution
ENV_VARS=$(env | awk -F = '{printf " \\$%s", $1}')

# Substitute environment variables in the template
envsubst "$ENV_VARS" < /etc/nginx/conf.d/default.template > /etc/nginx/conf.d/default.conf

# Test nginx configuration
nginx -t

if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid"
    echo "Starting Nginx with caching proxy on port 3128"
    echo "Remote server: $REMOTE"
    nginx -g 'daemon off;'
else
    echo "Nginx configuration test failed"
    exit 1
fi
EOF

# Make startup script executable
chmod +x start.sh

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  fxproxy:
    build: .
    ports:
      - "80:80"
    environment:
      - REMOTE=http://10.10.0.2:30120  # Change this to your FiveM server IP:port
    volumes:
      - ./cache:/srv/cache
    restart: unless-stopped
EOF

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit docker-compose.yml and change REMOTE=http://10.10.0.2:30120 to your actual server"
echo "2. Run: docker-compose up -d --build"
echo ""
echo "Files created in $(pwd):"
ls -la