# ============================================================
# STAGE 1: BUILDER
# ============================================================
FROM alpine:latest AS builder

RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

WORKDIR /build

COPY index.html blog.html /build/

# ============================================================
# STAGE 2: PRODUCTION
# ============================================================
FROM nginx:stable-alpine

# ============================================================
# METADATA
# ============================================================
LABEL maintainer="Praveen B"
LABEL description="DevOps Portfolio Website"
LABEL version="1.0"
LABEL org.opencontainers.image.source="https://github.com/MytPraveen/Portfolio"

# ============================================================
# SECURITY UPDATES
# ============================================================
RUN apk update && apk upgrade && rm -rf /var/cache/apk/* \
    && apk add --no-cache wget curl

# ============================================================
# REMOVE DEFAULT FILES
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
# CREATE NON ROOT USER
# ============================================================
RUN addgroup -g 1010 -S appgroup \
    && adduser -u 1010 -S appuser -G appgroup

# ============================================================
# CREATE REQUIRED DIRECTORIES
# ============================================================
RUN mkdir -p /tmp/nginx \
    /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp

# ============================================================
# OWNERSHIP
# ============================================================
RUN chown -R appuser:appgroup \
    /usr/share/nginx/html \
    /var/cache/nginx \
    /var/log/nginx \
    /etc/nginx/conf.d \
    /tmp/nginx

# ============================================================
# NGINX CONFIG
# ============================================================
RUN printf '%s\n' \
'pid /tmp/nginx/nginx.pid;' \
'events { worker_connections 1024; }' \
'http {' \
'    include /etc/nginx/mime.types;' \
'    default_type application/octet-stream;' \
'    sendfile on;' \
'    server_tokens off;' \
'' \
'    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;' \
'' \
'    server {' \
'        listen 8080;' \
'        server_name _;' \
'' \
'        root /usr/share/nginx/html;' \
'        index index.html;' \
'' \
'        add_header X-Frame-Options "SAMEORIGIN" always;' \
'        add_header X-Content-Type-Options "nosniff" always;' \
'        add_header X-XSS-Protection "1; mode=block" always;' \
'        add_header Referrer-Policy "strict-origin-when-cross-origin" always;' \
'        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;' \
'        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;' \
'' \
'        location / {' \
'            limit_req zone=mylimit burst=20 nodelay;' \
'            try_files $uri $uri/ /index.html;' \
'        }' \
'' \
'        location /health {' \
'            access_log off;' \
'            return 200 "healthy\n";' \
'            add_header Content-Type text/plain;' \
'        }' \
'' \
'        location ~ /\. {' \
'            deny all;' \
'        }' \
'' \
'        location ~* \.(pdf|jpg|jpeg|png|gif|ico|css|js|svg|webp)$ {' \
'            expires 30d;' \
'            add_header Cache-Control "public, immutable";' \
'            access_log off;' \
'        }' \
'    }' \
'}' \
> /etc/nginx/nginx.conf

# ============================================================
# RUN AS NON ROOT
# ============================================================
USER appuser

# ============================================================
# EXPOSE NON-PRIVILEGED PORT
# ============================================================
EXPOSE 8080

# ============================================================
# HEALTHCHECK
# ============================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

# ============================================================
# START NGINX
# ============================================================
ENTRYPOINT ["/entrypoint.sh"]
