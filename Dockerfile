# ============================================================
# STAGE 1: BUILDER
# Using specific version tag — fixes SonarQube docker:S6596
# ============================================================
FROM alpine:3.21 AS builder

# Single RUN layer — fixes SonarQube docker:S7031
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

WORKDIR /build
COPY index.html blog.html /build/

# ============================================================
# STAGE 2: PRODUCTION
# Using specific version tag — fixes SonarQube docker:S6596
# ============================================================
FROM nginx:1.27-alpine

LABEL maintainer="Praveen B" \
      description="DevOps Portfolio Website" \
      version="1.0" \
      org.opencontainers.image.source="https://github.com/MytPraveen/Portfolio" \
      org.opencontainers.image.title="devops-portfolio" \
      org.opencontainers.image.description="Personal DevOps portfolio with security hardening"

# Single RUN layer for all setup — fixes SonarQube docker:S7031
# Merges: security updates + remove defaults + user creation + permissions
RUN apk update && apk upgrade && rm -rf /var/cache/apk/* \
    && apk add --no-cache wget curl \
    && rm -rf /usr/share/nginx/html/* \
    && rm -f /etc/nginx/conf.d/default.conf \
    && addgroup -g 101 -S appgroup \
    && adduser -u 101 -S appuser -G appgroup

# Copy application files
COPY index.html /usr/share/nginx/html/
COPY blog.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/
COPY entrypoint.sh /entrypoint.sh

# nginx config + permissions + nginx user — single RUN fixes docker:S7031
RUN printf 'server {\n\
    listen 80;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
\n\
    add_header X-Frame-Options "SAMEORIGIN" always;\n\
    add_header X-Content-Type-Options "nosniff" always;\n\
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;\n\
    add_header X-XSS-Protection "1; mode=block" always;\n\
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;\n\
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()" always;\n\
\n\
    server_tokens off;\n\
    client_max_body_size 10M;\n\
\n\
    location / {\n\
        try_files $uri $uri/ =404;\n\
    }\n\
\n\
    location ~ /\\. {\n\
        deny all;\n\
        access_log off;\n\
        log_not_found off;\n\
    }\n\
\n\
    location ~* \\.(pdf|jpg|jpeg|png|gif|ico|css|js|svg|webp)$ {\n\
        expires 30d;\n\
        add_header Cache-Control "public, immutable";\n\
        access_log off;\n\
    }\n\
\n\
    location /health {\n\
        access_log off;\n\
        return 200 "healthy\\n";\n\
        add_header Content-Type text/plain;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf \
    && chmod +x /entrypoint.sh \
    && chown -R appuser:appgroup /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d \
    && sed -i 's/^user.*$//g' /etc/nginx/nginx.conf \
    && echo "user appuser;" >> /etc/nginx/nginx.conf

USER appuser

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
