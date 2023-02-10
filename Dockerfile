FROM debian:11.6 AS initial
ENV DEBIAN_FRONTEND=noninteractive

FROM debian:11.6 AS extract-assets
COPY --from=initial / /
ADD https://github.com/hugoalh/scan-virus-ghaction-assets/archive/refs/heads/main.tar.gz /tmp/scan-virus-ghaction-assets.tar.gz
RUN mkdir --parents --verbose /tmp/scan-virus-ghaction-assets
RUN tar --extract --file=/tmp/scan-virus-ghaction-assets.tar.gz --directory=/tmp/scan-virus-ghaction-assets --gzip --verbose

FROM debian:11.6 AS main
COPY --from=initial / /
RUN echo 'deb http://deb.debian.org/debian/ bullseye main contrib' > /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian/ bullseye main contrib' > /etc/apt/sources.list
RUN echo 'deb http://deb.debian.org/debian/ sid main contrib' > /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian/ sid main contrib' > /etc/apt/sources.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes upgrade
RUN apt-get --assume-yes install apt-transport-https curl gnupg
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN echo 'deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main' > /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes upgrade
RUN apt-get --assume-yes install powershell
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '1.1.0' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY configs/clamd.conf configs/freshclam.conf /etc/clamav/
RUN freshclam --verbose
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main /opt/hugoalh/scan-virus-ghaction/assets/
COPY lib/** /opt/hugoalh/scan-virus-ghaction/
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
