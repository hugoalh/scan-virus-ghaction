FROM debian:11 AS extract-powershell
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.3/powershell-7.2.3-linux-x64.tar.gz /tmp/powershell-7.2.3-linux-x64.tar.gz
RUN ["mkdir", "--parents", "--verbose", "/opt/microsoft/powershell/7"]
RUN ["tar", "--extract", "--file=/tmp/powershell-7.2.3-linux-x64.tar.gz", "--directory=/opt/microsoft/powershell/7", "--gzip", "--verbose"]
RUN ["ls", "--all", "--no-group", "--recursive", "/opt/microsoft/powershell/7"]

FROM debian:11 AS extract-assets
ADD https://github.com/hugoalh/scan-virus-ghaction-assets/archive/refs/heads/main.tar.gz /tmp/scan-virus-ghaction-assets.tar.gz
RUN ["mkdir", "--parents", "--verbose", "/tmp/scan-virus-ghaction-assets"]
RUN ["tar", "--extract", "--file=/tmp/scan-virus-ghaction-assets.tar.gz", "--directory=/tmp/scan-virus-ghaction-assets", "--gzip", "--verbose"]
RUN ["ls", "--all", "--no-group", "--recursive", "/tmp/scan-virus-ghaction-assets"]

FROM debian:11 AS main
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=extract-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7/
RUN ["ls", "--all", "--no-group", "--recursive", "/opt/microsoft/powershell/7"]
RUN ["chmod", "--verbose", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["apt-get", "--assume-yes", "update"]
RUN ["apt-get", "--assume-yes", "upgrade"]
RUN ["apt-get", "--assume-yes", "install", "ca-certificates", "clamav", "clamav-base", "clamav-daemon", "clamav-freshclam", "clamdscan", "git", "git-lfs", "gss-ntlmssp", "less", "libc6", "libgcc1", "libgssapi-krb5-2", "libicu67", "liblttng-ust0", "libssl1.1", "libstdc++6", "locales", "openssh-client", "yara", "zlib1g"]
RUN ["sed", "-i", "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g", "/etc/locale.gen"]
RUN ["locale-gen"]
RUN ["update-locale"]
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '0.3.3' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["clamconf", "--generate-config=freshclam.conf"]
RUN ["clamconf", "--generate-config=clamd.conf"]
RUN ["clamconf", "--generate-config=clamav-milter.conf"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam", "--verbose"]
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main/clamav-signatures-ignore-presets /opt/hugoalh/scan-virus-ghaction/clamav-signatures-ignore-presets/
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main/clamav-unofficial-signatures /opt/hugoalh/scan-virus-ghaction/clamav-unofficial-signatures/
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main/_compatibility.txt /opt/hugoalh/scan-virus-ghaction/_compatibility.txt
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main/_timestamp.txt /opt/hugoalh/scan-virus-ghaction/_timestamp.txt
COPY get-csv.psm1 get-gitcommits.psm1 main.ps1 test-stringisurl.psm1 /opt/hugoalh/scan-virus-ghaction/
COPY summary /opt/hugoalh/scan-virus-ghaction/summary/
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main/yara-rules /opt/hugoalh/scan-virus-ghaction/yara-rules/
RUN ["ls", "--all", "--no-group", "--recursive", "/opt/hugoalh/scan-virus-ghaction"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
