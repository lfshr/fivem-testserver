# Keep this up to date with the current recommended. No static url that I can find (haven't looked very hard)

#region configuration
$fxServerDownloadUri = 'https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/1915-4c469c830d3483cba3cdc54063b3120fec5bc168/server.zip'
$fxServerDataDownloadUri = 'https://github.com/citizenfx/cfx-server-data/archive/master.zip'

$solutionPath = "$PSScriptRoot\src\FiveM.TestServer\FiveM.TestServer.sln"
$buildProperties = [System.Collections.Generic.Dictionary[string,string]]::new()
$buildProperties.Add("Configuration", "Debug")
$buildProperties.Add("Platform", "Any CPU")
#endregion

#region boilerplate
$InformationPreference = "Continue" # Display information stream
$ErrorActionPreference = "Stop" # Stop on error
$symLinksToCreate = [System.Collections.Generic.Dictionary[string,string]]::new() # KVP Destination : Target
$ensures = [System.Collections.Generic.List[string]]::new()
#endregion

#region failfast checks
if(Test-Path -Path FXServer) {
    throw "Cannot create server when FXServer folder already exists"
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -Verb RunAs -FilePath Powershell.exe -ArgumentList "-noexit", "-File", $MyInvocation.MyCommand.Definition
    exit
}
#endregion

#region functions
function Import-MsBuild
{
    $vsPath = "$(${env:ProgramFiles(x86)})\Microsoft Visual Studio\2017"
    Get-ChildItem -Path $vsPath | 
        Select-Object -First 1 |
        ForEach-Object {
            Add-Type -Path (Join-Path -Path $_.FullName -ChildPath "MSBuild\15.0\Bin\amd64\Microsoft.Build.dll")
        }
}

function Add-ResourceRelativePathToProjects
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
                    ValueFromPipeline = $true)]
        [Microsoft.Build.Construction.SolutionFile]
        $Solution
    )

    $Solution.ProjectsInOrder | Where-Object ProjectType -ne 'SolutionFolder' | ForEach-Object {
        $relPath = 'bin'
        $parentGuid = $_.ParentProjectGuid
        $parent = $Solution.ProjectsByGuid[$parentGuid]
        $ensures.Add("ensure $($parent.ProjectName.ToLower())")

        # It got ugly with dupes, what you gunna do?
        while($parentGuid) {
            $parent = $Solution.ProjectsByGuid[$parentGuid]
            $relPath = Join-Path -Path $parent.ProjectName.ToLower() -ChildPath $relPath
            $parentGuid = $parent.ParentProjectGuid
        }

        $relPath = Join-Path -Path 'resources/[local]' -ChildPath $relPath
        $_ | Add-Member -MemberType NoteProperty -Name ResourceRelPath -Value $relPath -Force
    }
}

#region download fxserver and config
$fxRoot = New-Item -Path "$PSScriptRoot\FXServer" -ItemType Directory -Force
$tempPath = [System.IO.Path]::GetTempFileName() + ".zip"

try {
    Write-Information "Downloading & Extracting FxServer..."
    Invoke-WebRequest -Uri $fxServerDownloadUri -OutFile $tempPath
    Expand-Archive -Path $tempPath -DestinationPath "$fxRoot\server"
    Write-Information "Downloading & Extracting FxServer... Done!"

    Write-Information "Downloading & Extracting server-data..."
    Invoke-WebRequest -Uri $fxServerDataDownloadUri -OutFile $tempPath
    Expand-Archive -Path $tempPath -DestinationPath "$fxRoot"
    Rename-Item -Path "$fxRoot\cfx-server-data-master" -NewName "server-data"
    Write-Information "Downloading & Extracting server-data... Done!"
}
finally {
    Remove-Item $tempPath
}

New-Item -Path "$fxRoot\start-server.bat" -Value @"
@ECHO OFF
cd server-data
../server/run.cmd +exec server.cfg
pause
exit
"@
#endregion

#region Build and Symlink
Write-Information "Building..."
Import-MsBuild
$solution = [Microsoft.Build.Construction.SolutionFile]::Parse($solutionPath)
$solution | Add-ResourceRelativePathToProjects

$projectCollection = [Microsoft.Build.Evaluation.ProjectCollection]::new()
$solution.ProjectsInOrder | 
    Where-Object ProjectType -ne 'SolutionFolder' | 
    ForEach-Object {
    $project = $projectCollection.LoadProject($_.AbsolutePath)
    $project.Build()

    $symPath = "$fxRoot\server-data\$($_.ResourceRelPath)"
    $absoluteBuildPath = $project.DirectoryPath + "\" + $project.GetProperty("OutputPath").EvaluatedValue
    Write-Information "Creating symlink for $($_.ProjectName): `"$symPath`" <=> `"$absoluteBuildPath`""
    New-Item -ItemType "Junction" -Path $symPath -Target $absoluteBuildPath -Force
}

$configValue = Get-Content -Path "$PSScriptRoot\server.cfg.template" -Raw
$configValue = $configValue.Replace('${custom_resources}', [string]::Join("`n", $ensures))
New-Item -Path "$fxRoot\server-data\server.cfg" -Value $configValue

Write-Information "`n`nFinished building Development server. Please set the sv_licencekey and add the projects before running! - I'll get to having that automated next."