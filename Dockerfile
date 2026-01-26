FROM nginx:alpine

# 🔐 Fix OS-level vulnerabilities
RUN apk update \
 && apk upgrade \
 && rm -rf /var/cache/apk/*

# Clean default nginx files
RUN rm -rf /usr/share/nginx/html/*

# Copy application files
COPY index.html /usr/share/nginx/html/
COPY Praveen_B_Resume.pdf /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
