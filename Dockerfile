FROM debian:11.4 AS core
ENV DEBIAN_FRONTEND=noninteractive
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/7
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache

FROM debian:11.4 AS extract-powershell
COPY --from=core / /
ADD https://github.com/PowerShell/PowerShell/releases/download/v7.2.6/powershell-7.2.6-linux-x64.tar.gz /tmp/powershell-7.2.6-linux-x64.tar.gz
RUN ["mkdir", "--parents", "--verbose", "/opt/microsoft/powershell/7"]
RUN ["tar", "--extract", "--file=/tmp/powershell-7.2.6-linux-x64.tar.gz", "--directory=/opt/microsoft/powershell/7", "--gzip", "--verbose"]

FROM debian:11.4 AS extract-assets
COPY --from=core / /
ADD https://github.com/hugoalh/scan-virus-ghaction-assets/archive/refs/heads/main.tar.gz /tmp/scan-virus-ghaction-assets.tar.gz
RUN ["mkdir", "--parents", "--verbose", "/tmp/scan-virus-ghaction-assets"]
RUN ["tar", "--extract", "--file=/tmp/scan-virus-ghaction-assets.tar.gz", "--directory=/tmp/scan-virus-ghaction-assets", "--gzip", "--verbose"]

FROM debian:11.4 AS main
COPY --from=core / /
RUN ["apt-get", "--assume-yes", "update"]
RUN ["apt-get", "--assume-yes", "dist-upgrade"]
RUN ["apt-get", "--assume-yes", "install", "--target-release=bullseye", "build-essential", "ca-certificates", "curl", "gss-ntlmssp", "less", "libc6", "libgcc1", "libgssapi-krb5-2", "libicu67", "liblttng-ust0", "libssl1.1", "libssl-dev", "libstdc++6", "locales", "openssh-client", "zlib1g"]
COPY --from=extract-powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7/
RUN ["chmod", "--verbose", "a+x,o-w", "/opt/microsoft/powershell/7/pwsh"]
RUN ["ln", "-s", "/opt/microsoft/powershell/7/pwsh", "/usr/bin/pwsh"]
RUN ["sed", "-i", "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g", "/etc/locale.gen"]
RUN ["locale-gen"]
RUN ["update-locale"]
RUN ["apt-get", "--assume-yes", "install", "--target-release=sid", "clamav", "clamav-base", "clamav-daemon", "clamav-freshclam", "clamdscan", "git", "git-lfs", "yara"]
RUN ["curl", "-o-", "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh", "|", "bash"]
RUN ["nvm", "install", "16.17.0"]
RUN ["nvm", "use", "16.17.0"]
RUN ["node", "--version"]
RUN ["npm", "--global", "install", "npm@latest"]
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '0.5.5' -Scope 'AllUsers' -AcceptLicense -Verbose; Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam", "--verbose"]
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main /opt/hugoalh/scan-virus-ghaction/assets/
COPY assets.psm1 git.psm1 main.ps1 utility.psm1 /opt/hugoalh/scan-virus-ghaction/
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
