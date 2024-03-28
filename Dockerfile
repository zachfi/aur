FROM nginx:alpine
ARG arch
WORKDIR /repo
RUN ls -l
COPY repo/$arch/ /usr/share/nginx/html/
