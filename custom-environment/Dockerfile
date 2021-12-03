FROM --platform=$BUILDPLATFORM alpine:3.15 AS install-pwsh
ARG PWSH_VERSION=7.2.0
ARG PWSH_PACKAGEFILE=powershell-${PWSH_VERSION}-linux-alpine-x64.tar.gz
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/${PWSH_PACKAGENAME} /tmp/${PWSH_PACKAGEFILE}
ENV PWSH_INSTALLFOLDER=/opt/microsoft/powershell/7
RUN mkdir -p ${PWSH_INSTALLFOLDER}
RUN tar zxf /tmp/${PWSH_PACKAGEFILE} -C ${PWSH_INSTALLFOLDER} -v
FROM --platform=$BUILDPLATFORM alpine:3.15
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
ENV PWSH_INSTALLFOLDER=/opt/microsoft/powershell/7
COPY --from=install-pwsh ${PWSH_INSTALLFOLDER} ${PWSH_INSTALLFOLDER}
COPY alpine-repositories /etc/apk/repositories
RUN apk upgrade
RUN apk add --allow-untrusted --no-cache ca-certificates clamav@edgecommunity clamav-clamdscan@edgecommunity clamav-daemon@edgecommunity clamav-db@edgecommunity clamav-doc@edgecommunity clamav-libs@edgecommunity clamav-libunrar@edgecommunity clamav-milter@edgecommunity clamav-scanner@edgecommunity curl freshclam@edgecommunity git@edge icu-libs krb5-libs less libgcc libintl libssl1.1 libstdc++ lttng-ust@edge ncurses-terminfo-base openssh-client@edge tzdata userspace-rcu zlib
RUN ln -s ${PWSH_INSTALLFOLDER}/pwsh /usr/bin/pwsh
RUN chmod +x ${PWSH_INSTALLFOLDER}/pwsh
RUN export POWERSHELL_TELEMETRY_OPTOUT=1
RUN pwsh -NoLogo -NoProfile -Command "while(!(Test-Path -Path \$env:PSModuleAnalysisCachePath)) { Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'"; Start-Sleep -Seconds 5; }"
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
RUN freshclam
COPY main.ps1 /
CMD pwsh -NonInteractive /main.ps1
