FROM debian:11.6
ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'deb http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade
RUN apt-get --assume-yes install apt-utils ca-certificates curl gnupg gss-ntlmssp hwinfo less libc6 libgcc1 libgssapi-krb5-2 libicu67 libssl1.1 libstdc++6 locales openssh-client zlib1g
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo 'deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main' > /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade
RUN apt-get --assume-yes install powershell
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '1.2.1' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY configs/clamd.conf configs/freshclam.conf /etc/clamav/
RUN freshclam --verbose
COPY lib/** /opt/hugoalh/scan-virus-ghaction/lib/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/initial.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
