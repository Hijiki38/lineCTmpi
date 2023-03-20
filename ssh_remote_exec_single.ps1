# ワーキングディレクトリ、リモートサーバーのユーザー名とIPアドレス、開始・終了投影数
param(
  [string]$execID,
  [string]$User,
  [string]$TargetHost,
  [string]$istp,
  [string]$hstp,
  [string]$cpus,
  [string]$LocalWorkingDir
)

# ワーキングディレクトリ
#$LocalWorkingDir = "C:/Users/takum/Dropbox/Aoki_Lab/simulation/egs/lineCTmpi2"
$RemoteWorkingDir = "/home/${User}/lineCTmpi"
# リモートファイルとローカル保存先のパス
$RemoteResultFile = "$RemoteWorkingDir/share/share*.tar.gz"
$LocalDestination = "$LocalWorkingDir/result"

# リモートサーバーで実行するコマンド
$Command = "cd ${RemoteWorkingdir} && docker-compose up"

# 秘密鍵のパス
$SKey = "C:/Users/takum/.ssh/egs5_rsa"

# リモートに.envとして送るためのファイルtmp.txtを作成
Copy-Item -Path ${LocalWorkingDir}/.env -Destination ${LocalWorkingDir}/tmp${execID}.txt -Force
$content = Get-Content -Path ${LocalWorkingDir}/tmp${execID}.txt
$content = foreach ($line in $content) {
    if ($line -match "ISTP") {
        "PAR_ISTP=${istp}"
    } elseif($line -match "HSTP"){
	  "PAR_HSTP=${hstp}"
    } elseif($line -match "NUM_CPU"){
	  "NUM_CPU=${cpus}"
    } else {
        $line
    }
}
$content | Set-Content -Path ${LocalWorkingDir}/tmp${execID}.txt

# ローカルファイル(.env)をリモートにコピー
scp -i ${SKey} ${LocalWorkingDir}/tmp${execID}.txt ${User}@${TargetHost}:${RemoteWorkingDir}/.env

# tmp.txt消去
Remove-Item -Path ${LocalWorkingDir}/tmp${execID}.txt -Force

# SSH接続とコマンド実行
ssh -i ${SKey} ${User}@${TargetHost} ${Command}

# WSLリモートファイルをローカルにコピー
${FileList} = ssh -i ${SKey} ${User}@${TargetHost} "ls ${RemoteResultFile}"
foreach (${File} in ${FileList}) {
scp -i ${SKey} ${User}@${TargetHost}:${File} ${LocalDestination}
}

