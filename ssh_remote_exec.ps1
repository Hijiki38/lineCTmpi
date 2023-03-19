# リモートサーバーのユーザー名とIPアドレス
$User = "user"
$TargetHost = "192.168.0.41"

# ワーキングディレクトリ
$LocalWorkingDir = "C:/Users/takum/Dropbox/Aoki_Lab/simulation/egs/lineCTmpi2"
$RemoteWorkingDir = "/home/${User}/lineCTmpi"
# リモートファイルとローカル保存先のパス
$RemoteResultFile = "$RemoteWorkingDir/share/share*.tar.gz"
$LocalDestination = "$LocalWorkingDir/result"

# リモートサーバーで実行するコマンド
$Command = "cd ${RemoteWorkingdir} && docker-compose up"

# 秘密鍵のパス
$SKey = "C:/Users/takum/.ssh/egs5_rsa"


# ローカルファイル(.env)をリモートにコピー
scp -i ${SKey} ${LocalWorkingDir}/.env ${User}@${TargetHost}:${RemoteWorkingDir}/.env

# SSH接続とコマンド実行
ssh -i ${SKey} ${User}@${TargetHost} ${Command}

# WSLリモートファイルをローカルにコピー
${FileList} = ssh -i ${SKey} ${User}@${TargetHost} "ls ${RemoteResultFile}"
foreach (${File} in ${FileList}) {
scp -i ${SKey} ${User}@${TargetHost}:${File} ${LocalDestination}
}

