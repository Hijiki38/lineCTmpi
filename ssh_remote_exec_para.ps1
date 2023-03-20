param(
    [string]$currentDir
)

<#
### omenlt ###
#                     OMEN-LAPTOP
[string[]]$userlist = "user"
[string[]]$iplist   = "192.168.0.8"
[string[]]$istplist = "885"
[string[]]$hstplist = "895"
[string[]]$cpuslist = "8"
#>


### l8desk ###
#                     LEVEL8DESKTOP
[string[]]$userlist = "user"        
[string[]]$iplist   = "192.168.0.41"
[string[]]$istplist = "1079"    
[string[]]$hstplist = "1080"   
[string[]]$cpuslist = "10"     


<#
### both ###
#                     LEVEL8DESKTOP , OMEN-LAPTOP
[string[]]$userlist = "user"        , "user"
[string[]]$iplist   = "192.168.0.41", "192.168.0.8"
[string[]]$istplist = "864"         , "885"
[string[]]$hstplist = "865"         , "895"
[string[]]$cpuslist = "10"          , "8"
#>


$jobs = @()

$singleps1 = ${currentDir} + '\ssh_remote_exec_single.ps1'

for($i = 0; $i -lt $userlist.Length; $i++){
  $scriptBlock = {
    param($arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $eid)
    # MyScript.ps1の実行
    & powershell.exe -ExecutionPolicy Bypass -File $arg1 -execID $eid -User $arg2 -TargetHost $arg3 -istp $arg4 -hstp $arg5 -cpus $arg6 -LocalWorkingDir $arg7
  }
  $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $singleps1, $userlist[$i], $iplist[$i], $istplist[$i], $hstplist[$i], $cpuslist[$i], $currentDir, $i
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