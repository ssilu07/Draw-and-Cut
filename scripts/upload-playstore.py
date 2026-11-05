import os
import sys
import argparse

if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

DEFAULT_KEY = r'D:\htmlgames\TangledLine\play-key.json.json'
DEFAULT_PKG = 'com.royals.drawandcut'

def main():
    parser = argparse.ArgumentParser(description="Upload Android App Bundle (.aab) to Google Play Console")
    parser.add_argument('--aab', required=True, help="Path to .aab file")
    parser.add_argument('--key', default=DEFAULT_KEY, help="Path to Google Play Service Account JSON")
    parser.add_argument('--package', default=DEFAULT_PKG, help="Package Name")
    parser.add_argument('--track', default='production', choices=['production', 'internal', 'alpha', 'beta'], help="Release Track")
    parser.add_argument('--mapping', default=None, help="Path to ProGuard / R8 mapping.txt (optional)")
    parser.add_argument('--notes', default="Major update: Instant button responsiveness, seamless back navigation, 1-tap score sharing, gameplay stability, and performance optimizations.", help="Release notes in en-US")
    args = parser.parse_args()

    if not os.path.exists(args.aab):
        print(f"ERROR: AAB file not found at {args.aab}")
        sys.exit(1)

    if not os.path.exists(args.key):
        print(f"ERROR: Service account key not found at {args.key}")
        sys.exit(1)

    print("=" * 60)
    print("  🚀 DRAW & CUT - DIRECT GOOGLE PLAY STORE UPLOAD")
    print("=" * 60)
    print(f"Package Name : {args.package}")
    print(f"Target Track : {args.track.upper()}")
    print(f"AAB Path     : {args.aab}")
    print(f"AAB Size     : {round(os.path.getsize(args.aab) / (1024 * 1024), 2)} MB")
    print(f"Credentials  : {args.key}")

    creds = service_account.Credentials.from_service_account_file(
        args.key, scopes=['https://www.googleapis.com/auth/androidpublisher']
    )
    service = build('androidpublisher', 'v3', credentials=creds)

    # 1. Create Edit Session
    print("\n[1/5] Creating Google Play Console Edit Session...")
    edit_req = service.edits().insert(body={}, packageName=args.package)
    edit = edit_req.execute()
    edit_id = edit['id']
    print(f"  ✓ Edit Session ID: {edit_id}")

    try:
        # 2. Upload App Bundle
        print(f"\n[2/5] Uploading App Bundle ({round(os.path.getsize(args.aab) / (1024 * 1024), 2)} MB)...")
        media = MediaFileUpload(args.aab, mimetype='application/octet-stream', resumable=True)
        bundle_req = service.edits().bundles().upload(
            packageName=args.package, editId=edit_id, media_body=media
        )
        
        # Resumable upload progress loop
        response = None
        while response is None:
            status, response = bundle_req.next_chunk()
            if status:
                print(f"  ... Upload Progress: {int(status.progress() * 100)}%", end='\r')
        
        version_code = response['versionCode']
        print(f"\n  ✓ AAB Uploaded Successfully! Assigned Version Code: {version_code}")
        print(f"    SHA-1: {response.get('sha1', 'N/A')}")

        # 3. Upload Deobfuscation Mapping (if available)
        mapping_file = args.mapping
        if not mapping_file:
            cand = os.path.join(os.path.dirname(args.aab), "..", "..", "app", "build", "outputs", "mapping", "prodRelease", "mapping.txt")
            if os.path.exists(cand):
                mapping_file = cand

        if mapping_file and os.path.exists(mapping_file):
            print(f"\n[3/5] Uploading ProGuard / R8 Mapping File ({mapping_file})...")
            map_media = MediaFileUpload(mapping_file, mimetype='application/octet-stream')
            service.edits().deobfuscationfiles().upload(
                packageName=args.package,
                editId=edit_id,
                apkVersionCode=version_code,
                deobfuscationFileType='proguard',
                media_body=map_media
            ).execute()
            print("  ✓ Mapping file uploaded successfully.")
        else:
            print("\n[3/5] No mapping file found or specified. Skipping deobfuscation upload.")

        # 4. Update Release Track
        print(f"\n[4/5] Assigning Version Code {version_code} to Track '{args.track}'...")
        release_body = {
            'track': args.track,
            'releases': [{
                'name': f"1.2 ({version_code})",
                'versionCodes': [str(version_code)],
                'status': 'completed',
                'releaseNotes': [{
                    'language': 'en-US',
                    'text': args.notes
                }]
            }]
        }
        track_resp = service.edits().tracks().update(
            packageName=args.package,
            editId=edit_id,
            track=args.track,
            body=release_body
        ).execute()
        print(f"  ✓ Track '{args.track}' updated with status 'completed'.")

        # 5. Commit Edit
        print(f"\n[5/5] Committing release to Google Play Console...")
        commit_resp = service.edits().commit(
            packageName=args.package,
            editId=edit_id
        ).execute()
        print(f"  ✓ Edit committed successfully! ID: {commit_resp.get('id', edit_id)}")

        print("\n" + "=" * 60)
        print("  🎉 GOOGLE PLAY CONSOLE RELEASE PUBLISHED SUCCESSFULLY!")
        print("=" * 60)
        print(f"Package: {args.package}")
        print(f"Version: 1.2 (Code {version_code})")
        print(f"Track  : {args.track.upper()}")
        print("Your new release is now in Google Play Console Review / Published state.")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Error during release upload: {e}")
        try:
            service.edits().delete(packageName=args.package, editId=edit_id).execute()
            print("  Cleanup: Edit session discarded.")
        except Exception:
            pass
        sys.exit(1)

if __name__ == '__main__':
    main()
