from __future__ import print_function
import os
import glob
import sys
# parameter.py は gcp_client/ に置かれているため、本スクリプトの絶対位置を基準に追加する
# （カレントディレクトリ依存の相対パスだとSSH経由実行時に解決できない）
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.normpath(os.path.join(_THIS_DIR, '..', 'gcp_client')))
import parameter as p

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload
import google.auth

args = sys.argv      #引数を指定
file_path = args[1]  #入力ファイルのパス("/"まで)
all_files = glob.glob(F'{file_path}*.csv')

share_drive_id = p.share_drive_id

# Drive API 用のスコープ（GCE インスタンスに紐付いた SA から ADC 経由で取得する）
SCOPES = ['https://www.googleapis.com/auth/drive']

def upload_basic():
    """
    Drive 共有フォルダにCSVをアップロードします

    認証は GCE インスタンスにアタッチされたサービスアカウントを
    Application Default Credentials (ADC) 経由で利用します。
    キーファイルは不要です（インスタンステンプレートの --service-account と
    --scopes で権限が付与されている前提）。

    Returns:
        最後にアップロードしたファイルのID
    """

    # GCE メタデータサーバ経由でインスタンスの SA を取得
    creds, _ = google.auth.default(scopes=SCOPES)

    #ファイルのアップロード
    try:
        # create drive api client
        service = build('drive', 'v3', credentials=creds)

        for file_name in all_files:
            
            file_metadata = {
                'name': os.path.basename(file_name),
                'parents': [share_drive_id] 
            }
            
            media = MediaFileUpload(file_name,
                                    mimetype='text/csv')
            # pylint: disable=maybe-no-member
            file = service.files().create(body=file_metadata, media_body=media,
                                        fields='id', supportsAllDrives=True).execute()
            print(F'File ID: {file.get("id")}')

    except HttpError as error:
        print(F'An error occurred: {error}')
        file = None

    return file.get('id')

if __name__ == '__main__':
    upload_basic()