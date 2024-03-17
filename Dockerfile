FROM nginx:alpine
ARG arch
ARG repodir
COPY $repodir/$arch/ /usr/share/nginx/html/
