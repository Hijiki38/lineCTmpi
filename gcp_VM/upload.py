from __future__ import print_function
import os
import glob
import sys
sys.path.append('/home/zdc/lib')
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload
from google.oauth2 import service_account

args = sys.argv      #引数を指定
file_path = args[1]  #入力ファイルのパス("/"まで)
all_files = glob.glob(F'{file_path}*.csv')
keyfile_path = '/home/zdc/lineCTmpi/linectmpi-fcfdc9557818.json'
share_drive_id = '1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L'

def upload_basic():
    """Insert new file.
    Returns : Id's of the file uploaded

    Load pre-authorized user credentials from the environment.
    TODO(developer) - See https://developers.google.com/identity
    for guides on implementing OAuth2 for the application.
    """

    #サービスアカウントの認証
    creds = service_account.Credentials.from_service_account_file(keyfile_path)

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