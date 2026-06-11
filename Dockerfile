# Use stable lightweight nginx image
FROM nginx:stable-alpine

# Metadata (good practice)
LABEL maintainer="Praveen B"
LABEL description="DevOps Portfolio Website"
LABEL version="1.0"

# Install security updates
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

# Remove default nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy application files
COPY index.html /usr/share/nginx/html/
COPY blog.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/

# Create non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set proper ownership
RUN chown -R appuser:appgroup /usr/share/nginx/html

# Expose nginx port
EXPOSE 80

# Healthcheck (real-time good practice)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
