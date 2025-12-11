# Dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
# optional: remove default nginx index if you want
# RUN rm /usr/share/nginx/html/*.html
EXPOSE 80
