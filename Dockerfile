FROM debian:11.4 AS extract-assets
ENV DEBIAN_FRONTEND=noninteractive
ADD https://github.com/hugoalh/scan-virus-ghaction-assets/archive/refs/heads/main.tar.gz /tmp/scan-virus-ghaction-assets.tar.gz
RUN ["mkdir", "--parents", "--verbose", "/tmp/scan-virus-ghaction-assets"]
RUN ["tar", "--extract", "--file=/tmp/scan-virus-ghaction-assets.tar.gz", "--directory=/tmp/scan-virus-ghaction-assets", "--gzip", "--verbose"]

FROM debian:11.4 AS main
ENV DEBIAN_FRONTEND=noninteractive
ENV SNAPCRAFT_SETUP_CORE=1
RUN ["apt-get", "--assume-yes", "update"]
RUN ["apt-get", "--assume-yes", "install", "ca-certificates", "clamav", "clamav-base", "clamav-daemon", "clamav-freshclam", "clamdscan", "curl", "git", "git-lfs", "gss-ntlmssp", "less", "libc6", "libgcc1", "libgssapi-krb5-2", "libicu67", "liblttng-ust0", "libssl1.1", "libstdc++6", "locales", "openssh-client", "snapd", "yara", "zlib1g"]
RUN ["apt-get", "--assume-yes", "dist-upgrade"]
RUN ["service", "snapd", "start"]
RUN ["systemctl", "start", "snapd.service"]
RUN ["snap", "install", "core"]
RUN ["snap", "install", "node", "--channel=16/stable", "--classic"]
RUN ["snap", "install", "powershell", "--channel=latest/stable", "--classic"]
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '0.5.3' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN ["freshclam", "--verbose"]
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main /opt/hugoalh/scan-virus-ghaction/assets/
COPY assets.psm1 git.psm1 main.ps1 utility.psm1 /opt/hugoalh/scan-virus-ghaction/
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
