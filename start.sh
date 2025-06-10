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