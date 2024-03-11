FROM nginx:alpine
ARG arch
COPY repo/$arch/ /usr/share/nginx/html/
