FROM nginx:alpine
ARG arch
WORKDIR /repo
COPY repo/$arch/ /usr/share/nginx/html/
