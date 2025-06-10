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
proxy_cache_path /srv/cache levels=1:2 keys_zone=assets:48m max_size=90g inactive=30d;

log_format asset '$remote_addr - [$time_local] "$request" $status $body_bytes_sent $upstream_cache_status';

server {
    listen 3128;
    server_name _;
    
    location /files/ {
        access_log /dev/stdout asset;
        add_header X-Cache-Status $upstream_cache_status;
        
        proxy_cache_lock on;
        proxy_cache assets;
        proxy_cache_valid 200 301 302 1y;
        proxy_cache_key $request_uri$is_args$args;
        
        # Proxy settings
        proxy_pass ${REMOTE}$request_uri;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Cache headers
        proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        proxy_cache_lock_timeout 5s;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create startup script
cat > start.sh << 'EOF'
#!/bin/sh

# Check if REMOTE environment variable is set
if [ -z "$REMOTE" ]; then
    echo "ERROR: REMOTE environment variable is not set"
    echo "Please set REMOTE to the upstream server URL (e.g., http://example.com)"
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
  nginx-proxy:
    build: .
    ports:
      - "3128:3128"
    environment:
      - REMOTE=http://example.com  # Change this to your remote server
    volumes:
      - ./cache:/srv/cache
      - ./logs:/var/log/nginx
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3128/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit docker-compose.yml and change REMOTE=http://example.com to your actual server"
echo "2. Run: docker-compose up -d --build"
echo "3. Test with: curl http://localhost:3128/health"
echo ""
echo "Files created in $(pwd):"
ls -la