FROM debian:11.6 as powershell-extract
ENV COMPlus_EnableDiagnostics=0
ENV DEBIAN_FRONTEND=noninteractive
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_VERSION=7
ENV PS_VERSION=7.3.3
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_INSTALL_VERSION}
ENV PS_PACKAGE=powershell-${PS_VERSION}-linux-x64.tar.gz
ENV PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
ADD ${PS_PACKAGE_URL} /tmp/${PS_PACKAGE}
RUN mkdir --parents ${PS_INSTALL_FOLDER} --verbose
RUN tar --extract --gzip --file="/tmp/${PS_PACKAGE}" --directory="${PS_INSTALL_FOLDER}" --verbose

FROM debian:11.6 as main
ENV COMPlus_EnableDiagnostics=0
ENV DEBIAN_FRONTEND=noninteractive
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PS_INSTALL_VERSION=7
ENV PS_VERSION=7.3.3
ENV PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_INSTALL_VERSION}
ENV PS_PACKAGE=powershell-${PS_VERSION}-linux-x64.tar.gz
ENV PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
RUN echo 'deb http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian/ sid main contrib' >> /etc/apt/sources.list
RUN apt-get --assume-yes update
RUN apt-get --assume-yes dist-upgrade
RUN apt-get --assume-yes install apt-utils curl hwinfo
RUN apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
RUN apt-get --assume-yes install ca-certificates gss-ntlmssp less libc6 libgcc1 libgssapi-krb5-2 libicu67 libssl1.1 libstdc++6 locales openssh-client zlib1g
COPY --from=powershell-extract ${PS_INSTALL_FOLDER} ${PS_INSTALL_FOLDER}
RUN chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh
RUN ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
RUN locale-gen
RUN update-locale
RUN ["pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.4.0' -Scope 'AllUsers' -AcceptLicense -Verbose"]
RUN ["pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"]
COPY configs/clamd.conf configs/freshclam.conf /etc/clamav/
COPY lib/** /opt/hugoalh/scan-virus-ghaction/lib/
RUN ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/build.ps1"]
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/debug.ps1"]
