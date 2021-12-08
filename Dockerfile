FROM alpine:3.15 AS install-pwsh
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/powershell-7.2.0-linux-alpine-x64.tar.gz /tmp/powershell-7.2.0-linux-alpine-x64.tar.gz
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
RUN ["mkdir", "-p", "/opt/microsoft/powershell/7"]
RUN ["tar", "zxf", "/tmp/powershell-7.2.0-linux-alpine-x64.tar.gz", "-C", "/opt/microsoft/powershell/7", "-v"]
FROM alpine:3.15 AS main
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=install-pwsh /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "--allow-untrusted", "--no-cache", "ca-certificates", "clamav@edgecommunity", "clamav-clamdscan@edgecommunity", "clamav-daemon@edgecommunity", "clamav-db@edgecommunity", "clamav-doc@edgecommunity", "clamav-libs@edgecommunity", "clamav-libunrar@edgecommunity", "clamav-milter@edgecommunity", "clamav-scanner@edgecommunity", "curl", "freshclam@edgecommunity", "git@edge", "icu-libs", "krb5-libs", "less", "libgcc", "libintl", "libssl1.1", "libstdc++", "lttng-ust@edge", "ncurses-terminfo-base", "openssh-client@edge", "tzdata", "userspace-rcu", "zlib"]
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["chmod", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
RUN ["freshclam"]
COPY main.ps1 /opt/hugoalh/scan-virus-ghaction/main.ps1
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
