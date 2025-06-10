# Nginx Caching Proxy Docker Setup

## Files Required

1. `Dockerfile` - Main Docker image definition
2. `default.template` - Nginx configuration template
3. `start.sh` - Startup script with environment variable substitution
4. `docker-compose.yml` - Docker Compose configuration (optional)

## Building and Running

### Method 1: Docker Build
```bash
# Build the image
docker build -t nginx-proxy .

# Run the container
docker run -d \
  --name nginx-proxy \
  -p 3128:3128 \
  -e REMOTE=http://your-remote-server.com \
  -v $(pwd)/cache:/srv/cache \
  nginx-proxy
```

### Method 2: Docker Compose
```bash
# Update the REMOTE environment variable in docker-compose.yml first
# Then build and run
docker-compose up -d --build
```

## Configuration

### Environment Variables
- `REMOTE` - **Required**. The upstream server URL (e.g., `http://example.com`)

### Cache Configuration
- **Cache Path**: `/srv/cache`
- **Cache Size**: 90GB maximum
- **Cache Duration**: 1 year for successful responses
- **Cache Levels**: 1:2 (creates subdirectories for better file distribution)
- **Memory Zone**: 48MB for cache keys

### Usage
Once running, you can access cached files via:
```
http://localhost:3128/files/path/to/your/file
```

### Health Check
Check if the proxy is running:
```bash
curl http://localhost:3128/health
```

## Features
- Caching proxy with 90GB storage
- Custom log format showing cache status
- Cache lock to prevent multiple identical requests
- Proper proxy headers
- Health check endpoint
- Background cache updates
- Cache revalidation on stale content

## Logs
Access logs are written to stdout and show:
- Client IP
- Timestamp
- Request details
- Response status
- Bytes sent
- Cache hit/miss status