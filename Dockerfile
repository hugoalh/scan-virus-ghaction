FROM debian:11.6
ENV DEBIAN_FRONTEND=NonInteractive
ENV GHACTION_SCANVIRUS_CLAMAV_CONFIG=/etc/clamav/
ENV GHACTION_SCANVIRUS_CLAMAV_DATA=/var/lib/clamav/
ENV GHACTION_SCANVIRUS_PROGRAM_ROOT=/opt/hugoalh/scan-virus-ghaction/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS=/opt/hugoalh/scan-virus-ghaction/assets/
ENV GHACTION_SCANVIRUS_PROGRAM_LIB=/opt/hugoalh/scan-virus-ghaction/lib/
RUN echo 'deb http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN apt-get --assume-yes --quiet update
RUN apt-get --assume-yes --quiet install apt-utils curl hwinfo
RUN apt-get --assume-yes --quiet install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo 'deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main' > /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes --quiet update
RUN apt-get --assume-yes --quiet install powershell
RUN apt-get --assume-yes --quiet dist-upgrade
RUN apt-get --assume-yes --quiet autoremove
RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.4.1' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY configs/clamd.conf configs/freshclam.conf /etc/clamav/
COPY lib/** /opt/hugoalh/scan-virus-ghaction/lib/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/build.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
