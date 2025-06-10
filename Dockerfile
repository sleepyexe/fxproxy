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