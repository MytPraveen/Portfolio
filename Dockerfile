# Use lightweight NGINX image
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy portfolio files to nginx web root
COPY index.html /usr/share/nginx/html/
COPY Praveen\ B_Resume.pdf /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
