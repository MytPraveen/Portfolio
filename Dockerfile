# ============================================================
# Stage 1: Use stable lightweight nginx
# ============================================================
FROM nginx:stable-alpine

# ============================================================
# METADATA (best practice for traceability)
# ============================================================
LABEL maintainer="Praveen B"
LABEL description="DevOps Portfolio Website"
LABEL version="1.0"
LABEL org.opencontainers.image.source="https://github.com/MytPraveen/Portfolio"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"

# ============================================================
# SECURITY UPDATES
# ============================================================
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

# ============================================================
# REMOVE DEFAULT FILES
# ============================================================
RUN rm -rf /usr/share/nginx/html/*

# ============================================================
# COPY APPLICATION FILES
# ============================================================
COPY index.html /usr/share/nginx/html/
COPY blog.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/

# ============================================================
# NGINX CONFIGURATION WITH SECURITY HEADERS
# Fixes all OWASP ZAP warnings!
# ============================================================
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # ========== SECURITY HEADERS (Fixes ZAP warnings) ========== \
    # Prevents clickjacking attacks \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    \
    # Prevents MIME type sniffing \
    add_header X-Content-Type-Options "nosniff" always; \
    \
    # Enforces HTTPS (HSTS) - tells browsers to only use HTTPS \
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always; \
    \
    # XSS protection \
    add_header X-XSS-Protection "1; mode=block" always; \
    \
    # Controls referrer information \
    add_header Referrer-Policy "strict-origin-when-cross-origin" always; \
    \
    # Content Security Policy (prevents XSS and data injection) \
    add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; style-src '\''self'\'' '\''unsafe-inline'\'' https://fonts.googleapis.com; font-src '\''self'\'' https://fonts.gstatic.com; img-src '\''self'\'' data:; connect-src '\''self'\'' https://api.praveeninfra.online; frame-ancestors '\''none'\'';" always; \
    \
    # Controls browser features (Permissions Policy) \
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()" always; \
    \
    # Hide nginx version from attackers \
    server_tokens off; \
    \
    # ========== PERFORMANCE & SECURITY ========== \
    # Rate limiting to prevent DoS \
    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s; \
    \
    location / { \
        limit_req zone=mylimit burst=20 nodelay; \
        try_files $uri $uri/ =404; \
    } \
    \
    # Protect sensitive files \
    location ~ /\. { \
        deny all; \
    } \
    \
    location ~* \.(pdf|jpg|jpeg|png|gif|ico|css|js)$ { \
        expires 30d; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# ============================================================
# REMOVE DEFAULT NGINX CONFIG
# ============================================================
RUN rm -f /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true

# ============================================================
# CREATE NON-ROOT USER (Security best practice)
# ============================================================
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# ============================================================
# SET PROPER OWNERSHIP
# ============================================================
RUN chown -R appuser:appgroup /usr/share/nginx/html /var/cache/nginx /var/log/nginx

# ============================================================
# NGINX RUNS AS NON-ROOT USER
# ============================================================
RUN sed -i 's/^user.*$//g' /etc/nginx/nginx.conf && \
    echo "user appuser;" >> /etc/nginx/nginx.conf

# ============================================================
# EXPOSE PORT
# ============================================================
EXPOSE 80

# ============================================================
# HEALTHCHECK (For Kubernetes readiness/liveness probes)
# ============================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# ============================================================
# START NGINX IN FOREGROUND
# ============================================================
CMD ["nginx", "-g", "daemon off;"]
