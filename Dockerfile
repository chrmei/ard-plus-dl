FROM alpine:3.22

RUN apk add --no-cache bash curl yt-dlp jq util-linux perl

WORKDIR /app
COPY ard-plus-dl.sh graphql-queries.sh ./
RUN chmod +x /app/ard-plus-dl.sh && ln -s /app/ard-plus-dl.sh /usr/bin/download

ENV DOWNLOADS_DIR=/data/downloads
ENV XDG_STATE_HOME=/data
WORKDIR /data
