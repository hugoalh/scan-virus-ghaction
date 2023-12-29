# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM node:20-alpine3.19
# ENV DEBIAN_FRONTEND=noninteractive

# Environment variables for paths.
ENV SVGHA_CLAMAV_CONFIG=/etc/clamav
ENV SVGHA_CLAMAV_DATA=/var/lib/clamav
ENV SVGHA_ROOT=/opt/hugoalh/scan-virus-ghaction

# Environment variable for tool that forced.
ENV SVGHA_TOOLKIT=clamav

COPY config/alpine-repositories /etc/apk/repositories
RUN apk update
RUN apk --no-cache upgrade

# Install packages.
RUN apk --no-cache add clamav clamav-clamdscan clamav-daemon clamav-scanner freshclam git git-lfs

# Initialize ClamAV.
COPY config/clamd.conf config/freshclam.conf ${SVGHA_CLAMAV_CONFIG}/
RUN freshclam --verbose

COPY dist package.json package-lock.json ${SVGHA_ROOT}/
RUN cd $SVGHA_ROOT && npm install --omit=dev
RUN node $SVGHA_ROOT/dist/checkout.js
CMD node $SVGHA_ROOT/dist/main.js
