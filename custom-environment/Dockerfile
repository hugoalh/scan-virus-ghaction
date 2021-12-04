ARG PWSH_INSTALLFOLDER=/opt/microsoft/powershell/7
ARG PWSH_VERSION=7.2.0
ARG PWSH_PACKAGEFILE=powershell-${PWSH_VERSION}-linux-alpine-x64.tar.gz
FROM alpine:3.15 AS install-pwsh
ARG PWSH_INSTALLFOLDER
ARG PWSH_PACKAGEFILE
ARG PWSH_VERSION
ADD https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/${PWSH_PACKAGEFILE} /tmp/${PWSH_PACKAGEFILE}
ENV PS_INSTALL_FOLDER=${PWSH_INSTALLFOLDER}
RUN ["mkdir", "-p", "${PS_INSTALL_FOLDER}"]
RUN ["tar", "zxf", "/tmp/${PWSH_PACKAGEFILE}", "-C", "${PS_INSTALL_FOLDER}", "-v"]
FROM alpine:3.15
ARG PWSH_INSTALLFOLDER
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=${PWSH_INSTALLFOLDER}
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=install-pwsh ${PS_INSTALL_FOLDER} ${PS_INSTALL_FOLDER}
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "--allow-untrusted", "--no-cache", "ca-certificates", "clamav@edgecommunity", "clamav-clamdscan@edgecommunity", "clamav-daemon@edgecommunity", "clamav-db@edgecommunity", "clamav-doc@edgecommunity", "clamav-libs@edgecommunity", "clamav-libunrar@edgecommunity", "clamav-milter@edgecommunity", "clamav-scanner@edgecommunity", "curl", "freshclam@edgecommunity", "git@edge", "icu-libs", "krb5-libs", "less", "libgcc", "libintl", "libssl1.1", "libstdc++", "lttng-ust@edge", "ncurses-terminfo-base", "openssh-client@edge", "tzdata", "userspace-rcu", "zlib"]
RUN ["ln", "-s", "${PS_INSTALL_FOLDER}/pwsh", "/usr/bin/pwsh"]
RUN ["chmod", "+x", "${PS_INSTALL_FOLDER}/pwsh"]
RUN ["export", "POWERSHELL_TELEMETRY_OPTOUT=1"]
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
RUN ["freshclam"]
COPY main.ps1 /
CMD ["pwsh", "-NonInteractive", "/main.ps1"]
