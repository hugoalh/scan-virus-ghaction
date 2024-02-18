# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!



FROM debian:12.5

# Environment variable for tools, separate each name with comma (`,`) , must corresponding to install packages.
ENV SCANVIRUS_GHACTION_TOOLS=clamav,yara

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
RUN echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
RUN apt-get --assume-yes update

# Install packages.
RUN apt-get --assume-yes install apt-utils clamav clamav-base clamav-daemon clamav-freshclam clamdscan curl
RUN apt-get --assume-yes install --target-release=sid git git-lfs yara
# Optional: ca-certificates gss-ntlmssp less libc6 libgcc1 libgssapi-krb5-2 libicu67 libssl1.1 libstdc++6 locales openssh-client zlib1g

RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo "deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" >> /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install powershell
RUN apt-get --assume-yes dist-upgrade
RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.7.2' -Scope 'AllUsers' -AcceptLicense -Verbose"]

# Initialize ClamAV.
COPY config/clamd.conf config/freshclam.conf ${SCANVIRUS_GHACTION_CLAMAV_CONFIG}/
RUN freshclam --verbose

COPY lib/ ${SCANVIRUS_GHACTION_LIB_ROOT}/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/checkout.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
