$ErrorActionPreference = 'Stop'

& python (Join-Path $PSScriptRoot 'update_requirements.py')
exit $LASTEXITCODE
