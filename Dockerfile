FROM debian:11 AS extract-powershell
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.2/powershell-7.2.2-linux-x64.tar.gz /tmp/powershell-7.2.2-linux-x64.tar.gz
RUN ["mkdir", "-p", "/opt/microsoft/powershell/7"]
RUN ["tar", "zxf", "/tmp/powershell-7.2.2-linux-x64.tar.gz", "-C", "/opt/microsoft/powershell/7", "-v"]

FROM debian:11 AS setup
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
COPY --from=extract-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
RUN ["chmod", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["apt-get", "--assume-yes", "update"]
RUN ["apt-get", "--assume-yes", "--install-suggests", "upgrade"]
RUN ["apt-get", "--assume-yes", "--install-suggests", "install", "apt-transport-https", "automake", "bison", "ca-certificates", "clamav", "clamav-daemon", "curl", "flex", "gcc", "gnupg", "gss-ntlmssp", "less", "libc6", "libgcc1", "libgssapi-krb5-2", "libicu67", "liblttng-ust0", "libssl1.1", "libstdc++6", "libtool", "locales", "make", "openssh-client", "pkg-config", "yara", "zlib1g"]
RUN ["sed", "-i", "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g", "/etc/locale.gen"]
RUN ["locale-gen"]
RUN ["update-locale"]
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam", "--verbose"]

FROM blacktop/yara:w-rules AS get-yara-rules

# FROM debian:11 AS extract-yara-rules
# COPY --from=setup / /
# COPY --from=get-yara-rules /rules /opt/hugoalh/scan-virus-ghaction/yara-rules/source
# COPY extract-yara-rules.ps1 /opt/hugoalh/scan-virus-ghaction/
# RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/extract-yara-rules.ps1"]

FROM debian:11 AS main
COPY --from=setup / /
COPY main.ps1 /opt/hugoalh/scan-virus-ghaction/
# COPY --from=extract-yara-rules /opt/hugoalh/scan-virus-ghaction/yara-rules/compile /opt/hugoalh/scan-virus-ghaction/yara-rules
COPY --from=get-yara-rules /rules /opt/hugoalh/scan-virus-ghaction/yara-rules
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
