$ErrorActionPreference = 'Stop';
Write-Host Starting build

cd docker

docker build -t whoami -f .

docker images