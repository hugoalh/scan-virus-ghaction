# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM node:20-bookworm
ENV DEBIAN_FRONTEND=noninteractive

# Environment variables for paths.
ENV SVGHA_CLAMAV_CONFIG=/etc/clamav
ENV SVGHA_CLAMAV_DATA=/var/lib/clamav
ENV SVGHA_ROOT=/opt/hugoalh/scan-virus-ghaction

# Environment variable for tool that forced.
ENV SVGHA_TOOLKIT=yara

RUN echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade

# Install packages.
RUN apt-get --assume-yes install apt-utils
RUN apt-get --assume-yes install --target-release=sid git git-lfs yara

# Initialize ClamAV.
# COPY config/clamd.conf config/freshclam.conf ${SVGHA_CLAMAV_CONFIG}/
# RUN freshclam --verbose

COPY dist package.json package-lock.json ${SVGHA_ROOT}/
RUN cd $SVGHA_ROOT && npm install --omit=dev
RUN node $SVGHA_ROOT/dist/checkout.js
CMD node $SVGHA_ROOT/dist/main.js
