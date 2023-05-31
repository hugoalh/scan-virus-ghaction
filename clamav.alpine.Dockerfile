# syntax=docker/dockerfile:1
# <Note> Do not reduce layers due to GitHub Packages have worse performance on big size layer!

FROM alpine:3.18 AS stage-env
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7

FROM stage-env AS stage-extract-powershell
ARG PWSH_TARFILEPATH=/tmp/powershell-linux-alpine-x64.tar.gz
ARG PWSH_VERSION=7.3.4
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-alpine-x64.tar.gz ${PWSH_TARFILEPATH}
RUN mkdir --parents --verbose $PS_INSTALL_FOLDER
RUN tar "--directory=$PS_INSTALL_FOLDER" --extract "--file=$PWSH_TARFILEPATH" --gzip --verbose



FROM stage-env

ENV GHACTION_SCANVIRUS_BUNDLE_TOOL=clamav

ENV GHACTION_SCANVIRUS_PROGRAM_ROOT=/opt/hugoalh/scan-virus-ghaction/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS=${GHACTION_SCANVIRUS_PROGRAM_ROOT}assets/
ENV GHACTION_SCANVIRUS_PROGRAM_LIB=${GHACTION_SCANVIRUS_PROGRAM_ROOT}lib/

# <ClamAV Only>
ENV GHACTION_SCANVIRUS_CLAMAV_CONFIG=/etc/clamav/
ENV GHACTION_SCANVIRUS_CLAMAV_DATA=/var/lib/clamav/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}clamav-unofficial/

# <YARA Only>
# ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}yara-unofficial/

# <Debug>
# RUN printenv

COPY assets/configs/alpine-repositories /etc/apk/repositories
RUN apk update
RUN apk --no-cache upgrade

RUN apk --no-cache add ca-certificates clamav clamav-clamdscan clamav-daemon clamav-scanner curl freshclam git git-lfs icu-libs krb5-libs less libgcc libintl libssl1.1 libstdc++ lttng-ust@edge ncurses-terminfo-base nodejs tzdata userspace-rcu zlib
# <Full Format>
# RUN apk --no-cache add ca-certificates clamav clamav-clamdscan clamav-daemon clamav-scanner curl freshclam git git-lfs icu-libs krb5-libs less libgcc libintl libssl1.1 libstdc++ lttng-ust@edge ncurses-terminfo-base nodejs tzdata userspace-rcu yara@edgetesting zlib

COPY --from=stage-extract-powershell ${PS_INSTALL_FOLDER} ${PS_INSTALL_FOLDER}
RUN chmod +x $PS_INSTALL_FOLDER/pwsh
RUN ln -s $PS_INSTALL_FOLDER/pwsh /usr/bin/pwsh
RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.5.0' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]

# <Debug>
# RUN clamconf --generate-config=clamd.conf
# RUN clamconf --generate-config=freshclam.conf

# <ClamAV Only>
COPY assets/clamav-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV}
COPY assets/configs/clamd.conf assets/configs/freshclam.conf ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}

# <YARA Only>
# COPY assets/yara-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA}

COPY lib/ ${GHACTION_SCANVIRUS_PROGRAM_LIB}

# <Debug>
# RUN ls --almost-all --escape --format=long --hyperlink=never --no-group --recursive --size --time-style=full-iso -1 ${GHACTION_SCANVIRUS_PROGRAM_ROOT}

# <ClamAV Only>
RUN freshclam --verbose

CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
