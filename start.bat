
@Echo off
set cmdstring="%~dp0clipbroad.ps1"

powershell start-job -filepath %cmdstring%
