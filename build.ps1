$ErrorActionPreference = 'Stop';
Write-Host Starting build

cd docker

docker build --pull -t whoami -f .

docker images