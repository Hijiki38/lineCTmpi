param(
    [string]$currentDir
)

$userlist = "user", "user"
$iplist = "192.168.0.41", "192.168.0.8"
$istplist = "100", "200"
$hstplist = "102", "202"
$jobs = @()

$singleps1 = ${currentDir} + '\ssh_remote_exec_single.ps1'

for($i = 0; $i -lt $userlist.Length; $i++){
  $scriptBlock = {
    param($arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $eid)
    # MyScript.ps1の実行
    & powershell.exe -ExecutionPolicy Bypass -File $arg1 -execID $eid -User $arg2 -TargetHost $arg3 -istp $arg4 -hstp $arg5 -LocalWorkingDir $arg6
  }
  $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $singleps1, $userlist[$i], $iplist[$i], $istplist[$i], $hstplist[$i], $currentDir, $i
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