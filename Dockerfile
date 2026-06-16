# ============================================================
# STAGE 1: BUILDER - For build-time optimizations
# ============================================================
FROM alpine:latest AS builder

RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

WORKDIR /build

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
# SECURITY UPDATES
# ============================================================
RUN apk update && apk upgrade && rm -rf /var/cache/apk/* \
    && apk add --no-cache wget curl

# ============================================================
# REMOVE DEFAULT NGINX FILES
# ============================================================
RUN rm -rf /usr/share/nginx/html/* \
    && rm -f /etc/nginx/conf.d/default.conf

# ============================================================
# COPY WEBSITE FILES
# ============================================================
COPY index.html /usr/share/nginx/html/
COPY blog.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/

# ============================================================
# COPY ENTRYPOINT
# ============================================================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ============================================================
# NGINX CONFIGURATION
# ============================================================
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-Content-Type-Options "nosniff" always; \
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    add_header Referrer-Policy "strict-origin-when-cross-origin" always; \
    add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; style-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; font-src '\''self'\'' https://fonts.gstatic.com; img-src '\''self'\'' data:; connect-src '\''self'\'' https://api.praveeninfra.online; frame-ancestors '\''none'\'';" always; \
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()" always; \
    \
    server_tokens off; \
    client_max_body_size 10M; \
    \
    location / { \
        try_files $uri $uri/ =404; \
    } \
    \
    location ~ /\. { \
        deny all; \
        access_log off; \
        log_not_found off; \
    } \
    \
    location ~* \.(pdf|jpg|jpeg|png|gif|ico|css|js|svg|webp)$ { \
        expires 30d; \
        add_header Cache-Control "public, immutable"; \
        access_log off; \
    } \
    \
    location /health { \
        access_log off; \
        return 200 "healthy\n"; \
        add_header Content-Type text/plain; \
    } \
}' > /etc/nginx/conf.d/default.conf

# ============================================================
# CREATE NON-ROOT USER
# ============================================================
RUN addgroup -g 1010 -S appgroup && \
    adduser -u 1010 -S appuser -G appgroup

# ============================================================
# PERMISSIONS
# ============================================================
RUN chown -R appuser:appgroup \
    /usr/share/nginx/html \
    /var/cache/nginx \
    /var/log/nginx \
    /etc/nginx/conf.d

# ============================================================
# RUN NGINX AS NON-ROOT
# ============================================================
RUN sed -i '/^user/d' /etc/nginx/nginx.conf && \
    echo "user appuser;" >> /etc/nginx/nginx.conf

# ============================================================
# SWITCH USER
# ============================================================
USER appuser

# ============================================================
# PORT
# ============================================================
EXPOSE 80

# ============================================================
# HEALTHCHECK
# ============================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# ============================================================
# ENTRYPOINT
# ============================================================
ENTRYPOINT ["/entrypoint.sh"]
