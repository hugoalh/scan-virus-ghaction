# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM debian:12.5-slim as stage-base
ENV DEBIAN_FRONTEND=noninteractive

# Environment variables for paths.
ENV SVGHA_CLAMAV_CONFIG=/etc/clamav
ENV SVGHA_CLAMAV_DATA=/var/lib/clamav
ENV SVGHA_ROOT=/opt/hugoalh/scan-virus-ghaction

RUN echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
RUN apt-get --assume-yes update && apt-get --assume-yes dist-upgrade



FROM stage-base as stage-extract-deno
ARG DENO_VERSION=1.41.0
RUN apt-get --assume-yes install unzip
ADD https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-x86_64-unknown-linux-gnu.zip /tmp/deno.zip
RUN unzip /tmp/deno.zip



FROM stage-base
COPY --from=stage-extract-deno /tmp/deno /opt/denoland/deno/deno
RUN chmod +x /opt/denoland/deno/deno && ln -s /opt/denoland/deno/deno /usr/bin/deno

# Install packages.
RUN apt-get --assume-yes install apt-utils clamav clamav-base clamav-daemon clamav-freshclam clamdscan
RUN apt-get --assume-yes install --target-release=sid git git-lfs yara

# Initialize ClamAV.
COPY config/clamd.conf config/freshclam.conf ${SVGHA_CLAMAV_CONFIG}/
RUN freshclam --verbose

COPY lib checkout.ts deno.jsonc main.ts ${SVGHA_ROOT}/
RUN cd $SVGHA_ROOT && deno cache checkout.ts main.ts
RUN deno run --allow-all --cached-only $SVGHA_ROOT/checkout.ts
CMD deno run --allow-all --cached-only $SVGHA_ROOT/main.ts
