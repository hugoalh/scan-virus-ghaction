FROM alpine:3.15 AS main
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/powershell-7.2.0-linux-alpine-x64.tar.gz /tmp/powershell-7.2.0-linux-alpine-x64.tar.gz
COPY alpine-repositories /etc/apk/repositories
COPY setup.sh /opt/hugoalh/scan-virus-ghaction/setup.sh
RUN ["sh", "/opt/hugoalh/scan-virus-ghaction/setup.sh"]
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
COPY main.ps1 /opt/hugoalh/scan-virus-ghaction/main.ps1
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
