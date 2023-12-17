# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM node:20-alpine3.19 as stage-env
ENV DEBIAN_FRONTEND=noninteractive

# Environment variables for paths.
ENV SVGHA_CLAMAV_CONFIG=/etc/clamav
ENV SVGHA_CLAMAV_DATA=/var/lib/clamav
ENV SVGHA_ROOT=/opt/hugoalh/scan-virus-ghaction
ENV SVGHA_ASSETS_ROOT=${SVGHA_ROOT}/assets
ENV SVGHA_ASSETS_CLAMAV=${SVGHA_ASSETS_ROOT}/clamav
ENV SVGHA_ASSETS_YARA=${SVGHA_ASSETS_ROOT}/yara
ENV SVGHA_DIST_ROOT=${SVGHA_ROOT}/dist
ENV SVGHA_SOFTWARESVERSIONFILE=${SVGHA_ROOT}/softwares.json

# Environment variable for tool that forced.
ENV SVGHA_TOOLFORCE=clamav



FROM stage-env as stage-build-svgha-dist
COPY ./ ${SVGHA_ROOT}/
RUN cd $SVGHA_ROOT && npm install
RUN cd $SVGHA_ROOT && npm run build



FROM stage-env as main
COPY config/alpine-repositories /etc/apk/repositories
RUN apk update
RUN apk --no-cache upgrade

# Install packages.
RUN apk --no-cache add clamav clamav-clamdscan clamav-daemon clamav-scanner freshclam git git-lfs

# Initialize ClamAV.
COPY config/clamd.conf config/freshclam.conf ${SVGHA_CLAMAV_CONFIG}/
RUN freshclam --verbose

COPY package.json ${SVGHA_ROOT}/package.json
COPY --from=stage ${SVGHA_DIST_ROOT}/ ${SVGHA_DIST_ROOT}/
RUN cd $SVGHA_ROOT && npm install --omit=dev
RUN ["node", "/opt/hugoalh/scan-virus-ghaction/dist/checkout.js"]
CMD ["node", "/opt/hugoalh/scan-virus-ghaction/dist/main.js"]
