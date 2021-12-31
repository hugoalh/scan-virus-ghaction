FROM alpine:3.15 AS install-powershell
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.1/powershell-7.2.1-linux-alpine-x64.tar.gz /tmp/powershell-7.2.1-linux-alpine-x64.tar.gz
RUN ["mkdir", "-p", "/opt/microsoft/powershell/7"]
RUN ["tar", "zxf", "/tmp/powershell-7.2.1-linux-alpine-x64.tar.gz", "-C", "/opt/microsoft/powershell/7", "-v"]
FROM alpine:3.15 AS yara-rules-assembler
ENV \
	DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
	LANG=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8 \
	PS_INSTALL_FOLDER=/opt/microsoft/powershell/7 \
	PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=install-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["chmod", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "--allow-untrusted", "--no-cache", "ca-certificates", "curl", "icu-libs", "krb5-libs", "less", "libgcc", "libintl", "libssl1.1", "libstdc++", "lttng-ust@edge", "ncurses-terminfo-base", "openssh-client@edge", "tzdata", "userspace-rcu", "yara@edgetest", "zlib"]
COPY yara/index.tsv yara/rules-assembler.ps1 /opt/hugoalh/scan-virus-ghaction/yara/
WORKDIR /opt/hugoalh/scan-virus-ghaction/yara
RUN ["pwsh", "-NonInteractive", "rules-assembler.ps1"]
WORKDIR /
FROM alpine:3.15 AS main
ENV \
	DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
	LANG=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8 \
	PS_INSTALL_FOLDER=/opt/microsoft/powershell/7 \
	PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=install-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["chmod", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "--allow-untrusted", "--no-cache", "ca-certificates", "clamav@edgecommunity", "clamav-clamdscan@edgecommunity", "clamav-daemon@edgecommunity", "clamav-db@edgecommunity", "clamav-doc@edgecommunity", "clamav-libs@edgecommunity", "clamav-libunrar@edgecommunity", "clamav-milter@edgecommunity", "clamav-scanner@edgecommunity", "curl", "freshclam@edgecommunity", "git@edge", "icu-libs", "krb5-libs", "less", "libgcc", "libintl", "libssl1.1", "libstdc++", "lttng-ust@edge", "ncurses-terminfo-base", "openssh-client@edge", "tzdata", "userspace-rcu", "yara@edgetest", "zlib"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam"]
COPY main.ps1 /opt/hugoalh/scan-virus-ghaction/
COPY --from=yara-rules-assembler /opt/hugoalh/scan-virus-ghaction/yara/rules.yarac /opt/hugoalh/scan-virus-ghaction/yara/
RUN ["pwsh", "-C", "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"]
RUN ["pwsh", "-C", "Install-Module -AcceptLicense -Name PowerShellGet -Scope AllUsers -Verbose"]
RUN ["pwsh", "-C", "Update-Module -AcceptLicense -Scope AllUsers -Verbose"]
RUN ["pwsh", "-C", "Install-Module -AcceptLicense -Name 'hugoalh.GitHubActionsToolkit' -Scope AllUsers -Verbose"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
