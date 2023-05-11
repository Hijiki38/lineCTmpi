# パラメータ設定（共通）
param(
    [string]$currentDir
)

[string]$sod = "40"
[string]$sdd = "80"
[string]$ptch = "0.01"
[string]$ttms = "240"
[string]$step = "720"
[string]$hist = "1250"
#    [string]$hist = "1250257"

# パラメータ設定（固有）
<#
### omenlt ###
#                     OMEN-LAPTOP
[string[]]$userlist = "user"
[string[]]$iplist   = "192.168.0.8"
[string[]]$istplist = "885"
[string[]]$hstplist = "895"
[string[]]$cpuslist = "8"
[string[]]$pntmlist = "3"   
#>

<#
### l8desk ###
#                     LEVEL8DESKTOP
[string[]]$userlist = "user"        
[string[]]$iplist   = "192.168.0.41"
[string[]]$istplist = "0"    
[string[]]$hstplist = "20"   
[string[]]$cpuslist = "10" 
[string[]]$pntmlist = "4"     
#>


### both ###
#                     LEVEL8DESKTOP , OMEN-LAPTOP
[string[]]$userlist = "user"        , "user"
[string[]]$iplist   = "192.168.0.41", "192.168.0.8"
[string[]]$istplist = "0"           , "0"
[string[]]$hstplist = "25"          , "15"
[string[]]$cpuslist = "10"          , "8"
[string[]]$pntmlist = "4"           , "4"  
#
#phantom 3:fourmetal, 4:BG


$jobs = @()

$singleps1 = ${currentDir} + '\ssh_remote_exec_single.ps1'

for($i = 0; $i -lt $userlist.Length; $i++){
  $scriptBlock = {
    param($a_file, $a_user, $a_host, $a_sod, $a_sdd, $a_ptch, $a_ttms, $a_step, $a_hist, $a_istp, $a_hstp, $a_cpus, $a_pntm, $a_wdir, $eid)
    # MyScript.ps1の実行
    & powershell.exe -ExecutionPolicy Bypass -File $a_file -execID $eid -User $a_user -TargetHost $a_host -sod $a_sod -sdd $a_sdd -ptch $a_ptch -ttms $a_ttms -step $a_step -hist $a_hist -istp $a_istp -hstp $a_hstp -cpus $a_cpus -pntm $a_pntm -LocalWorkingDir $a_wdir
  }
  $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $singleps1, $userlist[$i], $iplist[$i], $sod, $sdd, $ptch, $ttms, $step, $hist, $istplist[$i], $hstplist[$i], $cpuslist[$i], $pntmlist[$i], $currentDir,  $i
  $jobs += $job
}

# ジョブの完了を待機
Wait-Job $jobs

# ジョブ結果の取得
$results = $jobs | Receive-Job

# 結果の表示
foreach ($result in $results) {
  Write-Host $result
}