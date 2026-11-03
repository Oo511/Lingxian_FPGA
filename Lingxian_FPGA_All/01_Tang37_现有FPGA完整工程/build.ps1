param(
 [string]$Gowin='D:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe',
 [string]$BuildDirectory='D:/FPGA/lingxian_track37',
 [int]$PlaceOption=1,
 [int]$RouteOption=1,
 [switch]$Test32
)
$ErrorActionPreference='Stop'
$taskName=if($Test32){'music_32tone_test'}else{'music_perform'}
$taskReports=Join-Path $PSScriptRoot ('reports/'+$taskName)
$taskDownload=Join-Path $PSScriptRoot 'download'
$taskWork=Join-Path $BuildDirectory ($taskName+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Force $taskReports,$taskDownload,$taskWork | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'FPGA/src'),(Join-Path $PSScriptRoot 'FPGA/screen_board.gprj') -Destination $taskWork -Recurse
$taskProject=(Join-Path $taskWork 'screen_board.gprj').Replace('\','/')
$taskTop=if($Test32){'contest_spectrum_top'}else{'studio_board_top'}
@("open_project {$taskProject}",'set_option -use_cpu_as_gpio 1',("set_option -top_module "+$taskTop),
 ("set_option -place_option "+$PlaceOption),("set_option -route_option "+$RouteOption),'run all') | Set-Content -Encoding ASCII (Join-Path $taskWork 'build.tcl')
& $Gowin (Join-Path $taskWork 'build.tcl') | Tee-Object -FilePath (Join-Path $taskReports 'build.log')
if($LASTEXITCODE -or (Select-String (Join-Path $taskReports 'build.log') -Pattern '^ERROR' -Quiet)){throw 'FPGA build failed'}
$taskTiming=Get-Content -Raw (Join-Path $taskWork 'impl/pnr/screen_board_tr_content.html')
if($taskTiming -notmatch 'Numbers of Setup Violated Endpoints</td>\s*<td>0</td>' -or
 $taskTiming -notmatch 'Numbers of Hold Violated Endpoints</td>\s*<td>0</td>'){throw 'Timing failed; bitstream not published'}
Copy-Item -LiteralPath (Join-Path $taskWork 'impl/pnr/screen_board.fs') -Destination (Join-Path $taskDownload ($taskName+'.fs')) -Force
Copy-Item -Path (Join-Path $taskWork 'impl/pnr/*.html'),(Join-Path $taskWork 'impl/pnr/screen_board.rpt.txt') -Destination $taskReports -Force
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $taskDownload ($taskName+'.fs'))
