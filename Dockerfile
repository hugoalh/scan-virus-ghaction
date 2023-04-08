FROM debian:11.6
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade
RUN apt-get --assume-yes install apt-utils curl hwinfo
RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo 'deb http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN echo 'deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main' > /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade
RUN apt-get --assume-yes install powershell
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN apt-get --assume-yes autoremove
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.4.0' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY configs/clamd.conf configs/freshclam.conf /etc/clamav/
COPY lib/** /opt/hugoalh/scan-virus-ghaction/lib/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/build.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
