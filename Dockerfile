FROM mcr.microsoft.com/powershell:alpine-3.14
RUN ["apk", "update"]
RUN ["apk", "upgrade"]
RUN ["apk", "add", "clamav", "clamav-clamdscan", "clamav-daemon", "clamav-db", "clamav-doc", "clamav-libs", "clamav-libunrar", "clamav-milter", "clamav-scanner", "freshclam", "git"]
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
COPY main.ps1 /
CMD ["pwsh", "-NonInteractive", "/main.ps1"]
