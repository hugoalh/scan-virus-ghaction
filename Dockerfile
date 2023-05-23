FROM debian:11.7 AS stage-env
ENV DEBIAN_FRONTEND=noninteractive
ENV GHACTION_SCANVIRUS_CLAMAV_CONFIG=/etc/clamav/
ENV GHACTION_SCANVIRUS_CLAMAV_DATA=/var/lib/clamav/
ENV GHACTION_SCANVIRUS_PROGRAM_ROOT=/opt/hugoalh/scan-virus-ghaction/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS=${GHACTION_SCANVIRUS_PROGRAM_ROOT}assets/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}clamav-unofficial/
ENV GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}yara-unofficial/
ENV GHACTION_SCANVIRUS_PROGRAM_LIB=${GHACTION_SCANVIRUS_PROGRAM_ROOT}lib/
# RUN printenv

FROM stage-env AS stage-setup
RUN echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install apt-utils curl hwinfo
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
RUN echo "deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" >> /etc/apt/sources.list.d/microsoft.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install powershell
RUN apt-get --assume-yes dist-upgrade
# RUN apt-get --assume-yes autoremove
SHELL ["pwsh", "-NonInteractive", "-Command"]

# FROM stage-env AS stage-checkout
FROM stage-setup AS stage-checkout
COPY assets/clamav-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV}
COPY assets/configs/clamd.conf assets/configs/freshclam.conf ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}
COPY assets/yara-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA}
COPY lib/ ${GHACTION_SCANVIRUS_PROGRAM_LIB}
RUN Get-ChildItem -LiteralPath @(\$Env:GHACTION_SCANVIRUS_CLAMAV_CONFIG, \$Env:GHACTION_SCANVIRUS_PROGRAM_ROOT) -Recurse -File | ForEach-Object -Process { [String]\$Content = Get-Content -LiteralPath \$_.FullName -Raw -Encoding 'UTF8NoBOM'; \$Content = \$Content -ireplace '\r', ''; Set-Content -LiteralPath \$_.FullName -Value \$Content -Encoding 'UTF8NoBOM' }

FROM stage-setup AS stage-final
RUN Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose
RUN Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose
RUN Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.5.0' -Scope 'AllUsers' -AcceptLicense -Verbose
RUN Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose
# RUN clamconf --generate-config=clamd.conf
# RUN clamconf --generate-config=freshclam.conf
COPY --from=stage-checkout ${GHACTION_SCANVIRUS_CLAMAV_CONFIG} ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}
COPY --from=stage-checkout ${GHACTION_SCANVIRUS_PROGRAM_ROOT} ${GHACTION_SCANVIRUS_PROGRAM_ROOT}
RUN freshclam --verbose
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
