# Based of script used by jonathank/jenkins-jnlp-slave-windows
# https://github.com/JonCubed/docker-jenkins-jnlp-slave-windows

# Get OpenJDK nanoserver container
FROM openjdk:8-nanoserver as openjdk

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Remoting versions can be found in Remoting sub-project changelog
# https://github.com/jenkinsci/remoting/blob/master/CHANGELOG.md
ENV SLAVE_FILENAME=slave.jar \
    REMOTING_VERSION=3.27 \
    SLAVE_HASH_FILENAME=$SLAVE_FILENAME.sha1

# Get the Slave from the Jenkins Artifacts Repository
RUN Invoke-WebRequest "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/$env:REMOTING_VERSION/remoting-$env:REMOTING_VERSION.jar" -OutFile $env:SLAVE_FILENAME -UseBasicParsing; \
    Invoke-WebRequest "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/$env:REMOTING_VERSION/remoting-$env:REMOTING_VERSION.jar.sha1" -OutFile $env:SLAVE_HASH_FILENAME -UseBasicParsing; \
    if ((Get-FileHash $env:SLAVE_FILENAME -Algorithm SHA1).Hash -ne $(Get-Content $env:SLAVE_HASH_FILENAME)) {exit 1};



# Build FlyWay only image
FROM microsoft/windowsservercore as flyway

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV FLYWAY_VERSION=5.2.1

ENV FLYWAY_FILENAME=flyway-commandline-$FLYWAY_VERSION-windows-x64.zip

ENV FLYWAY_HASH_FILENAME=$FLYWAY_FILENAME.sha1

# Get FlyWay
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest "https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/$env:FLYWAY_VERSION/$env:FLYWAY_FILENAME" -OutFile $env:FLYWAY_FILENAME -UseBasicParsing; \
    Invoke-WebRequest "https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/$env:FLYWAY_VERSION/$env:FLYWAY_HASH_FILENAME" -OutFile $env:FLYWAY_HASH_FILENAME -UseBasicParsing; \
    if ((Get-FileHash $env:FLYWAY_FILENAME -Algorithm SHA1).Hash -ne $(Get-Content $env:FLYWAY_HASH_FILENAME)) {exit 1};

RUN Expand-Archive $env:FLYWAY_FILENAME .\\flyway; \
    Move-Item -Path .\\flyway\\flyway-$env:FLYWAY_VERSION\\* -Destination .\\flyway; \
    Remove-Item .\\flyway\\flyway-$env:FLYWAY_VERSION



# Build Git only image
FROM microsoft/nanoserver as git

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV GIT_VERSION=2.19.1 \
    GIT_TAG=v2.19.1.windows.1

ENV GIT_FILENAME=MinGit-$GIT_VERSION-64-bit.zip \
    GIT_HASH_FILENAME=$GIT_FILENAME.sha256 \
    GIT_RELEASE_NOTES_FILENAME=releaseNotes.html

# Get Git
RUN Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/$env:GIT_TAG/$env:GIT_FILENAME" -OutFile $env:GIT_FILENAME -UseBasicParsing;\
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/tag/$env:GIT_TAG" -OutFile $env:GIT_RELEASE_NOTES_FILENAME -UseBasicParsing; \
    Select-String $env:GIT_RELEASE_NOTES_FILENAME -Pattern "\"<td>$env:GIT_FILENAME</td>\"" -Context 1 \
    | Select-Object -ExpandProperty Context \
    | Select-Object -ExpandProperty DisplayPostContext \
    | Select-String -Pattern '[a-f0-9]{64}' \
    | % { $_.Matches } \
    | % { $_.Value } \
    > $env:GIT_HASH_FILENAME; \
    if ((Get-FileHash $env:GIT_FILENAME -Algorithm SHA256).Hash -ne $(Get-Content $env:GIT_HASH_FILENAME)) {exit 1};

RUN Expand-Archive $env:GIT_FILENAME .\git;



# Build off nanoserver container
FROM microsoft/dotnet-framework:4.7.2-sdk

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV JAVA_HOME="c:\\Program Files\\openjdk" \
    JENKINS_HOME="c:\\Program Files\\jenkins" \
    GIT_HOME="c:\\Program Files\\git" \
    FLAYWAY_HOME="c:\\Program Files\\flyway" \
    SQL_EXPRESS_DOWNLOAD_URL="https://download.microsoft.com/download/2/A/5/2A5260C3-4143-47D8-9823-E91BB0121F94/SQLEXPR_x64_ENU.exe"

RUN Invoke-WebRequest -Uri $env:SQL_EXPRESS_DOWNLOAD_URL -OutFile sqlexpress.exe ; \
    Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /q, /x:setup ; \
    .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ; \
    Remove-Item -Recurse -Force sqlexpress.exe, setup

RUN stop-service MSSQL`$SQLEXPRESS ; \
    set-itemproperty -path 'HKLM:\\software\\microsoft\\microsoft sql server\\mssql12.SQLEXPRESS\\mssqlserver\\supersocketnetlib\\tcp\\ipall' -name tcpdynamicports -value '' ; \
    set-itemproperty -path 'HKLM:\\software\\microsoft\\microsoft sql server\\mssql12.SQLEXPRESS\\mssqlserver\\supersocketnetlib\\tcp\\ipall' -name tcpport -value 1433 ; \
    set-itemproperty -path 'HKLM:\\software\\microsoft\\microsoft sql server\\mssql12.SQLEXPRESS\\mssqlserver\\' -name LoginMode -value 2 ; \
    secedit /export /cfg .\\secpol.cfg ; \
    (gc .\\secpol.cfg).replace('PasswordComplexity = 1', 'PasswordComplexity = 0') | Out-File .\\secpol.cfg ; \
    secedit /configure /db c:\\windows\\security\\local.sdb /cfg .\\secpol.cfg /areas SECURITYPOLICY ; \
    Remove-Item -Force .\\secpol.cfg

RUN setx /M PATH $($env:Path.TrimEnd(';') + ';' + $env:JAVA_HOME + '\\bin;' + $env:GIT_HOME + '\\cmd;' + $env:GIT_HOME + '\\usr\\bin;' + $env:FLAYWAY_HOME + ';')

#Copy launch script used by entry point
COPY "slave-launch.ps1" ".\\slave-launch.ps1"

# Copy Java into the container
COPY --from=openjdk "C:\\ojdkbuild" "$JAVA_HOME"

# Copy Jenkins JNLP Slave into the container
COPY --from=openjdk ".\\slave.jar" ".\\slave.jar"

# Copy FlyWay into container
COPY --from=flyway ".\\flyway" "$FLAYWAY_HOME"

# Copy Git into container
COPY --from=git ".\\git" "$GIT_HOME"

ENTRYPOINT .\\slave-launch.ps1