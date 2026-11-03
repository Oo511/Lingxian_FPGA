param([string]$IcarusLibrary='', [string[]]$Testbenches=@('tb_link','tb_tx','tb_i2s','tb_latency','tb_modulation','tb_music','tb_contest','tb_guide','tb_effects','tb_system'))
$ErrorActionPreference='Stop'
if(-not $PSBoundParameters.ContainsKey('Testbenches')){
 $Testbenches=@('tb_recorded_track_switch37','tb_touch_recovery36','tb_touch_recording36','tb_encoder_volume31','tb_master_volume31','tb_master_dac31','tb_encoder_studio35','tb_encoder_display35','tb_expression34','tb_demo_controls34','tb_studio_loop','tb_studio_top','tb_studio_pixels','tb_studio_display','tb_instrument_compat','tb_test32_demo')
}
if(-not $IcarusLibrary) {
 $taskDir=Get-Item $PSScriptRoot
 while($taskDir -and -not(Test-Path (Join-Path $taskDir.FullName 'tmp/tools/iverilog/Library'))) {$taskDir=$taskDir.Parent}
 if(-not $taskDir){throw 'Supply -IcarusLibrary.'}
 $IcarusLibrary=Join-Path $taskDir.FullName 'tmp/tools/iverilog/Library'
}
$taskTemp=Join-Path $env:TEMP ('dual_sim_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $taskTemp | Out-Null
Copy-Item -LiteralPath $IcarusLibrary -Destination (Join-Path $taskTemp 'iv') -Recurse
$taskBin=Join-Path $taskTemp 'iv/bin';$taskIvl=Join-Path $taskTemp 'iv/lib/ivl'
$env:PATH=$taskBin+';'+(Join-Path $taskTemp 'iv/mingw-w64/bin')+';'+$env:PATH
Copy-Item -Path (Join-Path (Split-Path $PSScriptRoot) 'src/*.v'),(Join-Path $PSScriptRoot '*.v'),(Join-Path $PSScriptRoot '*.hex') -Destination $taskTemp
$taskOut=Join-Path $PSScriptRoot 'results';New-Item -ItemType Directory -Force $taskOut | Out-Null
Push-Location $taskTemp
try {
 foreach($taskBench in $Testbenches) {
  & "$taskBin/iverilog.exe" -B $taskIvl -g2012 -s $taskBench -o test.vvp @(Get-ChildItem '*.v' | ForEach-Object Name)
  if($LASTEXITCODE){throw 'Compile failed'}
  & "$taskBin/vvp.exe" test.vvp | Tee-Object -FilePath (Join-Path $taskOut ($taskBench+'.log'))
  if($LASTEXITCODE){throw 'Simulation failed'}
 }
 foreach($taskDump in @('demo34_test32.csv','studio_drums.csv','studio_main.ppm','studio_picker.ppm','instruments.txt','selector_pixels.txt','contest_samples.txt','music_samples.txt','latency.txt','guitar_pitch.csv','effect_audition.csv','fx_pixels.txt','vibrato_audition.csv','three_instruments.csv','organ_glide.csv','triple_pixels.txt','latency_dac27.csv')) {if(Test-Path -LiteralPath $taskDump){Copy-Item -LiteralPath $taskDump -Destination $taskOut -Force}}
} finally {Pop-Location}


