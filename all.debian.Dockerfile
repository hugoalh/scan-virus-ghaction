# syntax=docker/dockerfile:1
# <Note> Do not create big size layers due to GitHub Packages have worse performance on those!

FROM debian:12.1

# <Switch> Debian only.
ENV DEBIAN_FRONTEND=noninteractive

ENV GHACTION_SCANVIRUS_BUNDLE_TOOL=all
ENV GHACTION_SCANVIRUS_PROGRAM_ROOT=/opt/hugoalh/scan-virus-ghaction
ENV GHACTION_SCANVIRUS_PROGRAM_ASSET=${GHACTION_SCANVIRUS_PROGRAM_ROOT}/assets
ENV GHACTION_SCANVIRUS_PROGRAM_LIB=${GHACTION_SCANVIRUS_PROGRAM_ROOT}/lib

# <Switch> Self install PowerShell only.
# ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7

# <Switch> ClamAV only.
ENV GHACTION_SCANVIRUS_CLAMAV_CONFIG=/etc/clamav
ENV GHACTION_SCANVIRUS_CLAMAV_DATA=/var/lib/clamav
ENV GHACTION_SCANVIRUS_PROGRAM_ASSET_CLAMAV=${GHACTION_SCANVIRUS_PROGRAM_ASSET}/clamav-unofficial

# <Switch> YARA only.
ENV GHACTION_SCANVIRUS_PROGRAM_ASSET_YARA=${GHACTION_SCANVIRUS_PROGRAM_ASSET}/yara-unofficial

RUN echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
RUN apt-get --assume-yes update

RUN apt-get --assume-yes install apt-utils clamav clamav-base clamav-daemon clamav-freshclam clamdscan curl
# <Full Format>
# RUN apt-get --assume-yes install apt-utils ca-certificates clamav clamav-base clamav-daemon clamav-freshclam clamdscan curl gss-ntlmssp less libc6 libgcc1 libgssapi-krb5-2 libicu67 libssl1.1 libstdc++6 locales openssh-client zlib1g

RUN apt-get --assume-yes install --target-release=sid git git-lfs yara
# <Full format>
# RUN apt-get --assume-yes install --target-release=sid git git-lfs yara

RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo "deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" >> /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install powershell
RUN apt-get --assume-yes dist-upgrade

# <Switch> Use on reduce layer.
# RUN apt-get --assume-yes autoremove
# RUN apt-get --assume-yes clean

RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.7.1' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY lib/ ${GHACTION_SCANVIRUS_PROGRAM_LIB}/

# <Debug>
# RUN clamconf --generate-config=clamd.conf
# RUN clamconf --generate-config=freshclam.conf

# <Switch> ClamAV only.
COPY configs/clamd.conf configs/freshclam.conf ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}/
RUN freshclam --verbose

RUN pwsh -NonInteractive /opt/hugoalh/scan-virus-ghaction/lib/setup.ps1

# <Debug>
# RUN ls --almost-all --escape --format=long --hyperlink=never --no-group --recursive --size --time-style=full-iso -1 ${GHACTION_SCANVIRUS_PROGRAM_ROOT}

CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
