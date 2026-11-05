import json
from google.oauth2 import service_account
from googleapiclient.discovery import build

key_file = r'D:\htmlgames\TangledLine\play-key.json.json'
creds = service_account.Credentials.from_service_account_file(
    key_file, scopes=['https://www.googleapis.com/auth/androidpublisher']
)
service = build('androidpublisher', 'v3', credentials=creds)
pkg = 'com.royals.drawandcut'

try:
    edit_req = service.edits().insert(body={}, packageName=pkg)
    edit = edit_req.execute()
    edit_id = edit['id']
    print(f'Successfully created edit session: {edit_id}')
    
    tracks = service.edits().tracks().list(packageName=pkg, editId=edit_id).execute()
    print('Available tracks:')
    for t in tracks.get('tracks', []):
        print(f"Track: {t.get('track')}")
        for r in t.get('releases', []):
            print(f"  Release name: {r.get('name')}, status: {r.get('status')}, versionCodes: {r.get('versionCodes')}")
            
    service.edits().delete(packageName=pkg, editId=edit_id).execute()
    print('Session closed cleanly.')
except Exception as e:
    print('Error connecting to Play Console API:', e)
