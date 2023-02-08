FROM debian:11.6 AS core
ENV DEBIAN_FRONTEND=noninteractive

FROM debian:11.6 AS extract-assets
COPY --from=core / /
ADD https://github.com/hugoalh/scan-virus-ghaction-assets/archive/refs/heads/main.tar.gz /tmp/scan-virus-ghaction-assets.tar.gz
RUN mkdir --parents --verbose /tmp/scan-virus-ghaction-assets
RUN tar --extract --file=/tmp/scan-virus-ghaction-assets.tar.gz --directory=/tmp/scan-virus-ghaction-assets --gzip --verbose

FROM debian:11.6 AS main
COPY --from=core / /
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install apt-transport-https curl gnupg
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" > /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install powershell
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN ["pwsh", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Update-Module -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -MinimumVersion '1.1.0' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY clamd.conf freshclam.conf /etc/clamav/
RUN freshclam --verbose
COPY --from=extract-assets /tmp/scan-virus-ghaction-assets/scan-virus-ghaction-assets-main /opt/hugoalh/scan-virus-ghaction/assets/
COPY assets.psm1 git.psm1 main.ps1 token.psm1 utility.psm1 /opt/hugoalh/scan-virus-ghaction/
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/main.ps1"]
