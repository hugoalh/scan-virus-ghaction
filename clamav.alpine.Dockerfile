# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM alpine:3.18 AS stage-env

# Environment variable for tools, separate each name with comma (`,`) , must corresponding to install packages.
ENV SCANVIRUS_GHACTION_TOOLS=clamav

# Environment variables for paths.
ENV SCANVIRUS_GHACTION_ROOT=/opt/hugoalh/scan-virus-ghaction
ENV SCANVIRUS_GHACTION_ASSETS_ROOT=${SCANVIRUS_GHACTION_ROOT}/assets
ENV SCANVIRUS_GHACTION_ASSETS_CLAMAV=${SCANVIRUS_GHACTION_ASSETS_ROOT}/clamav
ENV SCANVIRUS_GHACTION_ASSETS_YARA=${SCANVIRUS_GHACTION_ASSETS_ROOT}/yara
ENV SCANVIRUS_GHACTION_LIB_ROOT=${SCANVIRUS_GHACTION_ROOT}/lib
ENV SCANVIRUS_GHACTION_SOFTWARESVERSIONFILE=${SCANVIRUS_GHACTION_ROOT}/softwares.json

ENV DEBIAN_FRONTEND=noninteractive
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV SCANVIRUS_GHACTION_CLAMAV_CONFIG=/etc/clamav
ENV SCANVIRUS_GHACTION_CLAMAV_DATA=/var/lib/clamav



FROM stage-env AS stage-extract-powershell
ARG PWSH_TARFILEPATH=/tmp/powershell-linux-alpine-x64.tar.gz
ARG PWSH_VERSION=7.3.8
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-alpine-x64.tar.gz ${PWSH_TARFILEPATH}
RUN mkdir --parents --verbose $PS_INSTALL_FOLDER
RUN tar "--directory=$PS_INSTALL_FOLDER" --extract "--file=$PWSH_TARFILEPATH" --gzip --verbose



FROM stage-env
COPY config/alpine-repositories /etc/apk/repositories
RUN apk update
RUN apk --no-cache upgrade

# Install packages.
RUN apk --no-cache add ca-certificates clamav clamav-clamdscan clamav-daemon clamav-scanner curl freshclam git git-lfs icu-libs krb5-libs less libgcc libintl libssl1.1 libstdc++ lttng-ust@edge ncurses-terminfo-base tzdata userspace-rcu zlib

COPY --from=stage-extract-powershell ${PS_INSTALL_FOLDER}/ ${PS_INSTALL_FOLDER}/
RUN chmod +x $PS_INSTALL_FOLDER/pwsh
RUN ln -s $PS_INSTALL_FOLDER/pwsh /usr/bin/pwsh
RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.7.2' -Scope 'AllUsers' -AcceptLicense -Verbose"]

# Initialize ClamAV.
COPY config/clamd.conf config/freshclam.conf ${SCANVIRUS_GHACTION_CLAMAV_CONFIG}/
RUN freshclam --verbose

COPY lib/ ${SCANVIRUS_GHACTION_LIB_ROOT}/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/checkout.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
