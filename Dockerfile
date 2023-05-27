FROM debian:11.7 AS stage-env
ENV DEBIAN_FRONTEND=noninteractive \
	GHACTION_SCANVIRUS_CLAMAV_CONFIG=/etc/clamav/ \
	GHACTION_SCANVIRUS_CLAMAV_DATA=/var/lib/clamav/ \
	GHACTION_SCANVIRUS_PROGRAM_ROOT=/opt/hugoalh/scan-virus-ghaction/ \
	GHACTION_SCANVIRUS_PROGRAM_ASSETS=${GHACTION_SCANVIRUS_PROGRAM_ROOT}assets/ \
	GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}clamav-unofficial/ \
	GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA=${GHACTION_SCANVIRUS_PROGRAM_ASSETS}yara-unofficial/ \
	GHACTION_SCANVIRUS_PROGRAM_LIB=${GHACTION_SCANVIRUS_PROGRAM_ROOT}lib/
RUN printenv

FROM stage-env AS stage-setup
RUN <<ENDOFRUN
	echo "deb http://deb.debian.org/debian/ sid main contrib" >> /etc/apt/sources.list
	apt-get --assume-yes update
	apt-get --assume-yes install apt-utils curl hwinfo
	apt-get --assume-yes install --target-release=sid clamav clamav-base clamav-daemon clamav-freshclam clamdscan git git-lfs nodejs yara
	curl https://packages.microsoft.com/keys/microsoft.asc --output /etc/apt/trusted.gpg.d/microsoft.asc
	echo "deb https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" >> /etc/apt/sources.list.d/microsoft.list
	apt-get --assume-yes update
	apt-get --assume-yes install powershell
	apt-get --assume-yes dist-upgrade
	apt-get --assume-yes autoremove
	"pwsh", "-NonInteractive", "-Command", "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -Verbose"
	"pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'PowerShellGet' -MinimumVersion '2.2.5' -Scope 'AllUsers' -AcceptLicense -Verbose"
	"pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'hugoalh.GitHubActionsToolkit' -RequiredVersion '1.5.0' -Scope 'AllUsers' -AcceptLicense -Verbose"
	"pwsh", "-NonInteractive", "-Command", "Install-Module -Name 'psyml' -Scope 'AllUsers' -AcceptLicense -Verbose"
	# RUN clamconf --generate-config=clamd.conf
	# RUN clamconf --generate-config=freshclam.conf
ENDOFRUN

FROM stage-env AS stage-checkout
COPY assets/clamav-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV}
COPY assets/configs/clamd.conf assets/configs/freshclam.conf ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}
COPY assets/yara-unofficial/ ${GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA}
COPY lib/ ${GHACTION_SCANVIRUS_PROGRAM_LIB}
# RUN ls --almost-all --escape --format=long --hyperlink=never --no-group --recursive --size --time-style=full-iso -1 ${GHACTION_SCANVIRUS_PROGRAM_ROOT}

FROM stage-setup AS stage-final
COPY --from=stage-checkout ${GHACTION_SCANVIRUS_CLAMAV_CONFIG} ${GHACTION_SCANVIRUS_CLAMAV_CONFIG}
RUN freshclam --verbose
COPY --from=stage-checkout ${GHACTION_SCANVIRUS_PROGRAM_ROOT} ${GHACTION_SCANVIRUS_PROGRAM_ROOT}
CMD ["pwsh", "-NonInteractive", "/opt/hugoalh/scan-virus-ghaction/lib/main.ps1"]
