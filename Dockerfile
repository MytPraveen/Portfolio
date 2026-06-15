# ============================================================
# STAGE 1: BUILDER - For any build-time dependencies
# ============================================================
FROM alpine:latest AS builder

# Install any build tools if needed (currently none for static site)
# This stage is reserved for future needs like:
# - Minifying CSS/JS
# - Optimizing images
# - Compiling assets

RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

# Create working directory
WORKDIR /build

# Copy source files that need processing
COPY index.html blog.html /build/

# ============================================================
# STAGE 2: FINAL - Production image
# ============================================================
FROM nginx:stable-alpine

# ============================================================
# METADATA
# ============================================================
LABEL maintainer="Praveen B"
LABEL description="DevOps Portfolio Website"
LABEL version="1.0"
LABEL org.opencontainers.image.source="https://github.com/MytPraveen/Portfolio"
LABEL org.opencontainers.image.title="devops-portfolio"
LABEL org.opencontainers.image.description="Personal DevOps portfolio website with security hardening"

# ============================================================
# SECURITY UPDATES (Single RUN layer)
# ============================================================
RUN apk update && apk upgrade && rm -rf /var/cache/apk/* \
    && apk add --no-cache wget curl

# ============================================================
# REMOVE DEFAULT NGINX FILES
# ============================================================
RUN rm -rf /usr/share/nginx/html/* \
    && rm -f /etc/nginx/conf.d/default.conf

# ============================================================
# COPY FILES FROM BUILDER (if any processing was done)
# For static site, copy directly from local
# ============================================================
COPY index.html /usr/share/nginx/html/
COPY blog.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/

# ============================================================
# COPY ENTRYPOINT SCRIPT
# ============================================================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ============================================================
# NGINX CONFIGURATION WITH SECURITY HEADERS (Optimized single RUN)
# ============================================================
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # Security Headers - Fixes OWASP ZAP warnings \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-Content-Type-Options "nosniff" always; \
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    add_header Referrer-Policy "strict-origin-when-cross-origin" always; \
    add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; style-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; font-src '\''self'\'' https://fonts.gstatic.com; img-src '\''self'\'' data:; connect-src '\''self'\'' https://api.praveeninfra.online; frame-ancestors '\''none'\'';" always; \
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()" always; \
    \
    # Performance & Security \
    server_tokens off; \
    client_max_body_size 10M; \
    \
    # Rate limiting \
    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s; \
    \
    location / { \
        limit_req zone=mylimit burst=20 nodelay; \
        try_files $uri $uri/ =404; \
    } \
    \
    # Protect hidden files \
    location ~ /\. { \
        deny all; \
        access_log off; \
        log_not_found off; \
    } \
    \
    # Static assets caching \
    location ~* \.(pdf|jpg|jpeg|png|gif|ico|css|js|svg|webp)$ { \
        expires 30d; \
        add_header Cache-Control "public, immutable"; \
        access_log off; \
    } \
    \
    # Health check endpoint \
    location /health { \
        access_log off; \
        return 200 "healthy\n"; \
        add_header Content-Type text/plain; \
    } \
}' > /etc/nginx/conf.d/default.conf

# ============================================================
# CREATE NON-ROOT USER (Security best practice)
# ============================================================
RUN addgroup -g 101 -S appgroup && adduser -u 101 -S appuser -G appgroup

# ============================================================
# SET PROPER OWNERSHIP
# ============================================================
RUN chown -R appuser:appgroup /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# ============================================================
# NGINX RUNS AS NON-ROOT USER
# ============================================================
RUN sed -i 's/^user.*$//g' /etc/nginx/nginx.conf \
    && echo "user appuser;" >> /etc/nginx/nginx.conf

# ============================================================
# SWITCH TO NON-ROOT USER
# ============================================================
USER appuser

# ============================================================
# EXPOSE PORT
# ============================================================
EXPOSE 80

# ============================================================
# HEALTHCHECK
# ============================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# ============================================================
# ENTRYPOINT (Fixes SonarQube CMD warning)
# ============================================================
ENTRYPOINT ["/entrypoint.sh"]
