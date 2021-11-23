FROM mcr.microsoft.com/powershell:alpine-3.14
COPY alpine-repositories /etc/apk/repositories
RUN ["apk", "upgrade"]
RUN ["apk", "add", "clamav@edgecommunity", "clamav-clamdscan@edgecommunity", "clamav-daemon@edgecommunity", "clamav-db@edgecommunity", "clamav-doc@edgecommunity", "clamav-libs@edgecommunity", "clamav-libunrar@edgecommunity", "clamav-milter@edgecommunity", "clamav-scanner@edgecommunity", "freshclam@edgecommunity", "git@edge", "--allow-untrusted"]
COPY clamd-minify.conf /etc/clamav/clamd.conf
COPY freshclam-minify.conf /etc/clamav/freshclam.conf
COPY main.ps1 /
CMD ["pwsh", "-NonInteractive", "/main.ps1"]
