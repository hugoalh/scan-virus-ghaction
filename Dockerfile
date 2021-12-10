FROM alpine:3.15 AS main
ENV \
	DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
	LANG=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8 \
	PS_INSTALL_FOLDER=/opt/microsoft/powershell/7 \
	PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/powershell-7.2.0-linux-alpine-x64.tar.gz /tmp/powershell-7.2.0-linux-alpine-x64.tar.gz
COPY alpine-repositories /etc/apk/repositories
COPY main.ps1 setup.sh /opt/hugoalh/scan-virus-ghaction/
RUN ["sh", "/opt/hugoalh/scan-virus-ghaction/setup.sh"]
RUN ["rm", "-f", "/opt/hugoalh/scan-virus-ghaction/setup.sh"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
