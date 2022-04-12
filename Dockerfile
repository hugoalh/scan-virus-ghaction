FROM alpine:3.15 AS extract-powershell
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.2/powershell-7.2.2-linux-alpine-x64.tar.gz /tmp/powershell-7.2.2-linux-alpine-x64.tar.gz
RUN ["mkdir", "-p", "/opt/microsoft/powershell/7"]
RUN ["tar", "zxf", "/tmp/powershell-7.2.2-linux-alpine-x64.tar.gz", "-C", "/opt/microsoft/powershell/7", "-v"]

FROM alpine:3.15 AS setup
ENV \
	DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
	LANG=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8 \
	PS_INSTALL_FOLDER=/opt/microsoft/powershell/7 \
	PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=extract-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["chmod", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "--allow-untrusted", "--no-cache", "ca-certificates", "clamav@edgecommunity", "clamav-clamdscan@edgecommunity", "clamav-daemon@edgecommunity", "clamav-db@edgecommunity", "clamav-doc@edgecommunity", "clamav-libs@edgecommunity", "clamav-libunrar@edgecommunity", "clamav-milter@edgecommunity", "clamav-scanner@edgecommunity", "curl", "freshclam@edgecommunity", "git@edge", "icu-libs", "krb5-libs", "less", "libgcc", "libintl", "libssl1.1", "libstdc++", "lttng-ust@edge", "ncurses-terminfo-base", "openssh-client@edge", "tzdata", "userspace-rcu", "yara@edgetest", "zlib"]
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam", "--verbose"]

FROM blacktop/yara:w-rules AS get-yara-rules

FROM alpine:3.15 AS extract-yara-rules
COPY --from=setup / /
COPY --from=get-yara-rules /rules /opt/hugoalh/scan-virus-ghaction/yara-rules
COPY extract-yara-rules.ps1 /opt/hugoalh/scan-virus-ghaction/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/extract-yara-rules.ps1"]

FROM alpine:3.15 AS main
COPY --from=setup / /
COPY main.ps1 /opt/hugoalh/scan-virus-ghaction/
COPY --from=extract-yara-rules /opt/hugoalh/scan-virus-ghaction/yara-rules.yarac /opt/hugoalh/scan-virus-ghaction/
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
