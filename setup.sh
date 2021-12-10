# $<Syntax>$ https://busybox.net/downloads/BusyBox.html
echo "Setup PowerShell."
mkdir -p /opt/microsoft/powershell/7
tar zxf /tmp/powershell-7.2.0-linux-alpine-x64.tar.gz -C /opt/microsoft/powershell/7
rm -f /tmp/powershell-7.2.0-linux-alpine-x64.tar.gz
ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
chmod a+x,o-w /opt/microsoft/powershell/7/pwsh
echo "Setup main system."
apk update
apk upgrade
apk add --allow-untrusted --no-cache ca-certificates clamav@edgecommunity clamav-clamdscan@edgecommunity clamav-daemon@edgecommunity clamav-db@edgecommunity clamav-doc@edgecommunity clamav-libs@edgecommunity clamav-libunrar@edgecommunity clamav-milter@edgecommunity clamav-scanner@edgecommunity curl freshclam@edgecommunity git@edge icu-libs krb5-libs less libgcc libintl libssl1.1 libstdc++ lttng-ust@edge ncurses-terminfo-base openssh-client@edge tzdata userspace-rcu zlib
