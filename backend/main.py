from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File, BackgroundTasks, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from supabase import create_client, Client
import os
import requests
import io
import re
import hashlib

from datetime import datetime, timedelta
from typing import Optional
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload, MediaIoBaseUpload
from google.oauth2.service_account import Credentials
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2.credentials import Credentials as UserCredentials
from cryptography.fernet import Fernet
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="Secure Cloud Platform API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS - Restricted origins for production
allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,https://yourdomain.com").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# Security setup
SUPABASE_URL = os.getenv("SUPABASE_URL", "your-supabase-url")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "your-supabase-key")

ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY", Fernet.generate_key().decode())
GOOGLE_CREDENTIALS_PATH = os.getenv("GOOGLE_CREDENTIALS_PATH", "credentials.json")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "your-client-id")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "your-client-secret")

# Initialize encryption
cipher_suite = Fernet(ENCRYPTION_KEY.encode())

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
security = HTTPBearer()

# Google Drive setup
def get_drive_service():
    try:
        credentials = Credentials.from_service_account_file(
            GOOGLE_CREDENTIALS_PATH,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        return build('drive', 'v3', credentials=credentials)
    except Exception as e:
        raise HTTPException(status_code=500, detail="Google Drive service unavailable")

def get_user_drive_service(encrypted_access_token: str, encrypted_refresh_token: str):
    try:
        # Decrypt tokens
        access_token = decrypt_token(encrypted_access_token)
        refresh_token = decrypt_token(encrypted_refresh_token) if encrypted_refresh_token else None
        
        credentials = UserCredentials(
            token=access_token,
            refresh_token=refresh_token,
            token_uri='https://oauth2.googleapis.com/token',
            client_id=GOOGLE_CLIENT_ID,
            client_secret=GOOGLE_CLIENT_SECRET,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        return build('drive', 'v3', credentials=credentials), credentials
    except Exception as e:
        raise HTTPException(status_code=500, detail="User drive service unavailable")

def create_user_folder(drive_service, user_email: str, parent_folder_id: str = None):
    """Create a folder for the user in Google Drive"""
    try:
        # Use root if no parent folder specified
        if not parent_folder_id:
            parent_folder_id = 'root'
        
        # Check if folder already exists
        query = f"name='{user_email}' and mimeType='application/vnd.google-apps.folder' and '{parent_folder_id}' in parents and trashed=false"
        existing_folders = drive_service.files().list(q=query, fields="files(id,name)").execute()
        
        if existing_folders.get('files'):
            return existing_folders['files'][0]['id']
        
        # Create new folder
        folder_metadata = {
            'name': user_email,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [parent_folder_id]
        }
        
        folder = drive_service.files().create(
            body=folder_metadata,
            fields='id,name'
        ).execute()
        
        return folder['id']
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create user folder: {str(e)}")

def get_user_email_from_token(user_id: str):
    """Get user email from Supabase user ID"""
    try:
        user = supabase.auth.admin.get_user_by_id(user_id)
        return user.user.email
    except Exception:
        return f"user_{user_id}"  # Fallback to user ID if email not available

def encrypt_token(token: str) -> str:
    return cipher_suite.encrypt(token.encode()).decode()

def decrypt_token(encrypted_token: str) -> str:
    return cipher_suite.decrypt(encrypted_token.encode()).decode()

def sanitize_filename(filename: str) -> str:
    # Remove dangerous characters and limit length
    sanitized = re.sub(r'[^\w\s.-]', '', filename)
    return sanitized[:255]

def verify_file_access(user_id: str, drive_id: str) -> bool:
    # Verify user owns the drive
    result = supabase.table("user_drives").select("user_id").eq("id", drive_id).eq("user_id", user_id).execute()
    return len(result.data) > 0

def refresh_user_token(drive_id: str, credentials: UserCredentials):
    try:
        credentials.refresh(GoogleRequest())
        # Encrypt tokens before storing
        encrypted_access = encrypt_token(credentials.token)
        encrypted_refresh = encrypt_token(credentials.refresh_token) if credentials.refresh_token else None
        
        supabase.table("user_drives").update({
            "access_token": encrypted_access,
            "refresh_token": encrypted_refresh
        }).eq("id", drive_id).execute()
        return credentials.token
    except Exception as e:
        raise HTTPException(status_code=401, detail="Token refresh failed")

# Models
class DriveConnect(BaseModel):
    drive_type: str
    access_token: str
    refresh_token: str
    drive_name: str

class ShareFile(BaseModel):
    public: bool = True
    expires_in_days: Optional[int] = None
    allow_download: bool = True
    allow_view: bool = True

class UserDriveConnect(BaseModel):
    authorization_code: str
    drive_name: str

class RevokeShare(BaseModel):
    file_id: str

# Supabase Authentication
def verify_supabase_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        user = supabase.auth.get_user(credentials.credentials)
        if not user.user:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user.user.id
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

# Auth handled by Supabase client-side - no server endpoints needed

@app.get("/user/drives")
@limiter.limit("30/minute")
async def get_user_drives(request: Request, user_id: str = Depends(verify_supabase_token)):
    try:
        result = supabase.table("user_drives").select("*").eq("user_id", user_id).execute()
        return {"drives": result.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get drives: {str(e)}")

@app.post("/user/connect-drive")
@limiter.limit("5/minute")
async def connect_user_drive(request: Request, drive_data: UserDriveConnect, user_id: str = Depends(verify_supabase_token)):
    # Check drive limit (max 4 drives per user)
    existing_drives = supabase.table("user_drives").select("id").eq("user_id", user_id).execute()
    if len(existing_drives.data) >= 4:
        raise HTTPException(status_code=400, detail="Maximum 4 drives allowed per user")
    
    try:
        # Exchange authorization code for tokens
        token_response = requests.post('https://oauth2.googleapis.com/token', data={
            'client_id': GOOGLE_CLIENT_ID,
            'client_secret': GOOGLE_CLIENT_SECRET,
            'code': drive_data.authorization_code,
            'grant_type': 'authorization_code',
            'redirect_uri': 'http://localhost:8000/oauth/callback'
        })
        
        if token_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Invalid authorization code")
        
        tokens = token_response.json()
        
        # Encrypt tokens before storing
        encrypted_access = encrypt_token(tokens['access_token'])
        encrypted_refresh = encrypt_token(tokens.get('refresh_token')) if tokens.get('refresh_token') else None
        
        result = supabase.table("user_drives").insert({
            "user_id": user_id,
            "drive_type": "personal",
            "access_token": encrypted_access,
            "refresh_token": encrypted_refresh,
            "drive_name": sanitize_filename(drive_data.drive_name),
            "created_at": datetime.utcnow().isoformat()
        }).execute()
        
        return {"message": "Drive connected successfully", "drive_id": result.data[0]["id"]}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Drive connection failed: {str(e)}")

@app.post("/connect-drive")
async def connect_drive(drive: DriveConnect, user_id: str = Depends(verify_supabase_token)):
    result = supabase.table("user_drives").insert({
        "user_id": user_id,
        "drive_type": drive.drive_type,
        "access_token": drive.access_token,
        "refresh_token": drive.refresh_token,
        "drive_name": drive.drive_name,
        "created_at": datetime.utcnow().isoformat()
    }).execute()
    
    return {"message": "Drive connected successfully", "drive_id": result.data[0]["id"]}

@app.get("/list-files")
async def list_files(user_id: str = Depends(verify_supabase_token)):
    # Placeholder - implement drive API integration
    return {"files": []}

@app.post("/upload-file")
async def upload_file(user_id: str = Depends(verify_supabase_token)):
    # Placeholder - implement file upload
    return {"message": "File upload endpoint"}

@app.get("/download-file/{file_id}")
async def download_file(file_id: str, user_id: str = Depends(verify_supabase_token)):
    # Placeholder - implement file download
    return {"message": "File download endpoint"}

@app.delete("/delete-file/{file_id}")
async def delete_file(file_id: str, user_id: str = Depends(verify_supabase_token)):
    # Placeholder - implement file deletion
    return {"message": "File deletion endpoint"}

@app.post("/shared/upload")
async def shared_upload(file: UploadFile = File(...), user_id: str = Depends(verify_supabase_token)):
    try:
        drive_service = get_drive_service()
        
        # Get user email and create user folder
        user_email = get_user_email_from_token(user_id)
        base_folder_id = os.getenv('GOOGLE_DRIVE_FOLDER_ID', 'root')
        user_folder_id = create_user_folder(drive_service, user_email, base_folder_id)
        
        # Upload to user's folder in shared drive
        file_metadata = {
            'name': sanitize_filename(file.filename),
            'parents': [user_folder_id]
        }
        
        media = MediaIoBaseUpload(
            io.BytesIO(await file.read()),
            mimetype=file.content_type or 'application/octet-stream'
        )
        
        drive_file = drive_service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id,name,size,mimeType'
        ).execute()
        
        # Store metadata in Supabase
        result = supabase.table("files").insert({
            "user_drive_id": None,
            "drive_file_id": drive_file['id'],
            "name": drive_file['name'],
            "type": drive_file.get('mimeType', 'unknown'),
            "size": int(drive_file.get('size', 0)),
            "folder_id": user_folder_id,
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat()
        }).execute()
        
        return {
            "file_id": result.data[0]["id"],
            "drive_file_id": drive_file['id'],
            "name": drive_file['name'],
            "size": drive_file.get('size', 0),
            "user_folder_id": user_folder_id
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@app.get("/shared/list")
async def shared_list(folder_id: str = "root", user_id: str = Depends(verify_supabase_token)):
    try:
        drive_service = get_drive_service()
        
        # List files in shared drive folder
        query = f"'{folder_id}' in parents and trashed=false"
        results = drive_service.files().list(
            q=query,
            fields="files(id,name,mimeType,size,modifiedTime,parents)"
        ).execute()
        
        return {"files": results.get('files', [])}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"List files failed: {str(e)}")

@app.get("/shared/download/{file_id}")
async def shared_download(file_id: str, user_id: str = Depends(verify_supabase_token)):
    try:
        # Get file metadata from Supabase
        result = supabase.table("files").select("*").eq("id", file_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="File not found")
        
        file_data = result.data[0]
        drive_service = get_drive_service()
        
        # Download from Google Drive
        request = drive_service.files().get_media(fileId=file_data['drive_file_id'])
        file_io = io.BytesIO()
        downloader = MediaIoBaseDownload(file_io, request)
        
        done = False
        while done is False:
            status, done = downloader.next_chunk()
        
        file_io.seek(0)
        
        return StreamingResponse(
            io.BytesIO(file_io.read()),
            media_type='application/octet-stream',
            headers={"Content-Disposition": f"attachment; filename={file_data['name']}"}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")

@app.delete("/shared/delete/{file_id}")
async def shared_delete(file_id: str, user_id: str = Depends(verify_supabase_token)):
    try:
        # Get file metadata from Supabase
        result = supabase.table("files").select("*").eq("id", file_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="File not found")
        
        file_data = result.data[0]
        drive_service = get_drive_service()
        
        # Delete from Google Drive
        drive_service.files().delete(fileId=file_data['drive_file_id']).execute()
        
        # Delete from Supabase
        supabase.table("files").delete().eq("id", file_id).execute()
        
        return {"message": "File deleted successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

@app.post("/shared/share/{file_id}")
async def shared_share(file_id: str, share_data: ShareFile, user_id: str = Depends(verify_supabase_token)):
    try:
        # Get file metadata from Supabase
        result = supabase.table("files").select("*").eq("id", file_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="File not found")
        
        file_data = result.data[0]
        drive_service = get_drive_service()
        
        # Create permission with expiration if specified
        permission = {
            'role': 'reader' if share_data.allow_view else 'writer',
            'type': 'anyone'
        }
        
        if share_data.expires_in_days:
            expiration_time = datetime.utcnow() + timedelta(days=share_data.expires_in_days)
            permission['expirationTime'] = expiration_time.isoformat() + 'Z'
        
        permission_result = drive_service.permissions().create(
            fileId=file_data['drive_file_id'],
            body=permission,
            fields='id'
        ).execute()
        
        # Generate public link
        if share_data.allow_download:
            public_link = f"https://drive.google.com/uc?id={file_data['drive_file_id']}&export=download"
        else:
            public_link = f"https://drive.google.com/file/d/{file_data['drive_file_id']}/view"
        
        # Calculate expiration date
        expires_at = None
        if share_data.expires_in_days:
            expires_at = (datetime.utcnow() + timedelta(days=share_data.expires_in_days)).isoformat()
        
        # Update Supabase with shared link and metadata
        supabase.table("files").update({
            "shared_link": public_link,
            "permission_id": permission_result['id'],
            "link_expires_at": expires_at,
            "shared_by": user_id,
            "shared_at": datetime.utcnow().isoformat()
        }).eq("id", file_id).execute()
        
        return {
            "shared_link": public_link,
            "permission_id": permission_result['id'],
            "expires_at": expires_at,
            "message": "File shared successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Share failed: {str(e)}")

@app.get("/user/list-files/{drive_id}")
async def list_user_files(drive_id: str, folder_id: str = "root", background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # List files in folder
        query = f"'{folder_id}' in parents and trashed=false"
        results = service.files().list(
            q=query,
            fields="files(id,name,mimeType,size,modifiedTime,parents)"
        ).execute()
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return {"files": results.get('files', [])}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"List files failed: {str(e)}")

@app.post("/user/upload-file/{drive_id}")
async def upload_user_file(drive_id: str, file: UploadFile = File(...), folder_id: str = "root", background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # Get user email and create user folder if uploading to root
        if folder_id == "root":
            user_email = get_user_email_from_token(user_id)
            folder_id = create_user_folder(service, user_email)
        
        # Upload file
        file_metadata = {
            'name': sanitize_filename(file.filename),
            'parents': [folder_id]
        }
        
        media = MediaIoBaseUpload(
            io.BytesIO(await file.read()),
            mimetype=file.content_type or 'application/octet-stream'
        )
        
        drive_file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id,name,size,mimeType'
        ).execute()
        
        # Store metadata
        supabase.table("files").insert({
            "user_drive_id": drive_id,
            "drive_file_id": drive_file['id'],
            "name": drive_file['name'],
            "type": drive_file.get('mimeType', 'unknown'),
            "size": int(drive_file.get('size', 0)),
            "folder_id": folder_id,
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat()
        }).execute()
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return {
            "file_id": drive_file['id'],
            "name": drive_file['name'],
            "size": drive_file.get('size', 0),
            "user_folder_id": folder_id
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@app.get("/user/download-file/{drive_id}/{file_id}")
async def download_user_file(drive_id: str, file_id: str, background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # Get file metadata
        file_metadata = service.files().get(fileId=file_id, fields='name').execute()
        
        # Download file
        request = service.files().get_media(fileId=file_id)
        file_io = io.BytesIO()
        downloader = MediaIoBaseDownload(file_io, request)
        
        done = False
        while done is False:
            status, done = downloader.next_chunk()
        
        file_io.seek(0)
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return StreamingResponse(
            io.BytesIO(file_io.read()),
            media_type='application/octet-stream',
            headers={"Content-Disposition": f"attachment; filename={file_metadata['name']}"}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")

@app.delete("/user/delete-file/{drive_id}/{file_id}")
async def delete_user_file(drive_id: str, file_id: str, background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # Delete file
        service.files().delete(fileId=file_id).execute()
        
        # Delete from database
        supabase.table("files").delete().eq("drive_file_id", file_id).eq("user_drive_id", drive_id).execute()
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return {"message": "File deleted successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Delete failed: {str(e)}")

@app.post("/user/share-file/{drive_id}/{file_id}")
async def share_user_file(drive_id: str, file_id: str, share_data: ShareFile, background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # Create permission with proper settings
        permission = {
            'role': 'reader' if share_data.allow_view else 'writer',
            'type': 'anyone'
        }
        
        if share_data.expires_in_days:
            expiration_time = datetime.utcnow() + timedelta(days=share_data.expires_in_days)
            permission['expirationTime'] = expiration_time.isoformat() + 'Z'
        
        permission_result = service.permissions().create(
            fileId=file_id,
            body=permission,
            fields='id'
        ).execute()
        
        # Generate appropriate link
        if share_data.allow_download:
            public_link = f"https://drive.google.com/uc?id={file_id}&export=download"
        else:
            public_link = f"https://drive.google.com/file/d/{file_id}/view"
        
        # Calculate expiration date
        expires_at = None
        if share_data.expires_in_days:
            expires_at = (datetime.utcnow() + timedelta(days=share_data.expires_in_days)).isoformat()
        
        # Update database with comprehensive sharing info
        supabase.table("files").update({
            "shared_link": public_link,
            "permission_id": permission_result['id'],
            "link_expires_at": expires_at,
            "shared_by": user_id,
            "shared_at": datetime.utcnow().isoformat()
        }).eq("drive_file_id", file_id).eq("user_drive_id", drive_id).execute()
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return {
            "shared_link": public_link,
            "permission_id": permission_result['id'],
            "expires_at": expires_at,
            "message": "File shared successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Share failed: {str(e)}")

@app.post("/shared/revoke/{file_id}")
async def revoke_shared_link(file_id: str, user_id: str = Depends(verify_supabase_token)):
    try:
        # Get file metadata
        result = supabase.table("files").select("*").eq("id", file_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="File not found")
        
        file_data = result.data[0]
        if not file_data.get('permission_id'):
            raise HTTPException(status_code=400, detail="No active share found")
        
        drive_service = get_drive_service()
        
        # Remove permission from Google Drive
        drive_service.permissions().delete(
            fileId=file_data['drive_file_id'],
            permissionId=file_data['permission_id']
        ).execute()
        
        # Clear sharing info in database
        supabase.table("files").update({
            "shared_link": None,
            "permission_id": None,
            "link_expires_at": None,
            "revoked_at": datetime.utcnow().isoformat(),
            "revoked_by": user_id
        }).eq("id", file_id).execute()
        
        return {"message": "Share link revoked successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Revoke failed: {str(e)}")

@app.post("/user/revoke/{drive_id}/{file_id}")
async def revoke_user_share(drive_id: str, file_id: str, background_tasks: BackgroundTasks = BackgroundTasks(), user_id: str = Depends(verify_supabase_token)):
    try:
        # Get drive credentials
        drive_result = supabase.table("user_drives").select("*").eq("id", drive_id).eq("user_id", user_id).execute()
        if not drive_result.data:
            raise HTTPException(status_code=404, detail="Drive not found")
        
        # Get file metadata
        file_result = supabase.table("files").select("*").eq("drive_file_id", file_id).eq("user_drive_id", drive_id).execute()
        if not file_result.data:
            raise HTTPException(status_code=404, detail="File not found")
        
        file_data = file_result.data[0]
        if not file_data.get('permission_id'):
            raise HTTPException(status_code=400, detail="No active share found")
        
        drive_data = drive_result.data[0]
        service, credentials = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
        
        # Remove permission from Google Drive
        service.permissions().delete(
            fileId=file_id,
            permissionId=file_data['permission_id']
        ).execute()
        
        # Clear sharing info in database
        supabase.table("files").update({
            "shared_link": None,
            "permission_id": None,
            "link_expires_at": None,
            "revoked_at": datetime.utcnow().isoformat(),
            "revoked_by": user_id
        }).eq("drive_file_id", file_id).eq("user_drive_id", drive_id).execute()
        
        # Check if token was refreshed
        if credentials.token != drive_data['access_token']:
            background_tasks.add_task(refresh_user_token, drive_id, credentials)
        
        return {"message": "Share link revoked successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Revoke failed: {str(e)}")

@app.get("/user/shared-files")
async def get_user_shared_files(user_id: str = Depends(verify_supabase_token)):
    try:
        result = supabase.table("files").select("*").eq("shared_by", user_id).not_.is_("shared_link", "null").execute()
        return {"shared_files": result.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get shared files: {str(e)}")

@app.post("/share-file/{file_id}")
async def share_file(file_id: str, user_id: str = Depends(verify_supabase_token)):
    # Placeholder - implement file sharing
    return {"message": "File sharing endpoint"}

@app.get("/search")
@limiter.limit("60/minute")
async def search_files(request: Request, q: str, user_id: str = Depends(verify_supabase_token)):
    try:
        files_result = supabase.table("files").select("*").ilike("name", f"%{q}%").execute()
        return {"files": files_result.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@app.get("/recent-files")
@limiter.limit("30/minute")
async def get_recent_files(request: Request, limit: int = 20, user_id: str = Depends(verify_supabase_token)):
    try:
        files_result = supabase.table("files").select("*").order("created_at", desc=True).limit(limit).execute()
        return {"files": files_result.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get recent files: {str(e)}")

@app.get("/favorites")
@limiter.limit("30/minute")
async def get_favorites(request: Request, user_id: str = Depends(verify_supabase_token)):
    try:
        result = supabase.table("files").select("*").eq("shared_by", user_id).limit(10).execute()
        return {"files": result.data}
    except Exception as e:
        return {"files": []}

@app.post("/toggle-favorite")
@limiter.limit("20/minute")
async def toggle_favorite(request: Request, favorite_data: dict, user_id: str = Depends(verify_supabase_token)):
    return {"message": "Favorite toggled"}

@app.post("/suggest-tags")
@limiter.limit("30/minute")
async def suggest_tags(request: Request, file_data: dict, user_id: str = Depends(verify_supabase_token)):
    try:
        file_name = file_data["file_name"].lower()
        tags = []
        
        if any(ext in file_name for ext in ['.jpg', '.png', '.gif', '.jpeg']):
            tags.extend(['image', 'photo', 'picture'])
        elif any(ext in file_name for ext in ['.pdf', '.doc', '.docx']):
            tags.extend(['document', 'text', 'office'])
        elif any(ext in file_name for ext in ['.mp4', '.avi', '.mov']):
            tags.extend(['video', 'media', 'entertainment'])
        elif any(ext in file_name for ext in ['.mp3', '.wav', '.flac']):
            tags.extend(['audio', 'music', 'sound'])
        
        if any(word in file_name for word in ['report', 'summary', 'analysis']):
            tags.append('report')
        if any(word in file_name for word in ['presentation', 'slides', 'ppt']):
            tags.append('presentation')
        
        return {"tags": list(set(tags))[:5]}
    except Exception as e:
        return {"tags": []}

# Background task to clean up expired links
async def cleanup_expired_links():
    try:
        current_time = datetime.utcnow().isoformat()
        expired_files = supabase.table("files").select("*").lt("link_expires_at", current_time).not_.is_("shared_link", "null").execute()
        
        for file_data in expired_files.data:
            try:
                if file_data.get('user_drive_id'):
                    # User drive file
                    drive_result = supabase.table("user_drives").select("*").eq("id", file_data['user_drive_id']).execute()
                    if drive_result.data:
                        drive_data = drive_result.data[0]
                        service, _ = get_user_drive_service(drive_data['access_token'], drive_data['refresh_token'])
                        service.permissions().delete(
                            fileId=file_data['drive_file_id'],
                            permissionId=file_data['permission_id']
                        ).execute()
                else:
                    # Shared drive file
                    drive_service = get_drive_service()
                    drive_service.permissions().delete(
                        fileId=file_data['drive_file_id'],
                        permissionId=file_data['permission_id']
                    ).execute()
                
                # Clear sharing info
                supabase.table("files").update({
                    "shared_link": None,
                    "permission_id": None,
                    "expired_at": current_time
                }).eq("id", file_data['id']).execute()
                
            except Exception as e:
                print(f"Failed to cleanup expired link for file {file_data['id']}: {e}")
                
    except Exception as e:
        print(f"Cleanup task failed: {e}")

# Add security middleware
from security_middleware import security_middleware
app.middleware("http")(security_middleware)

if __name__ == "__main__":
    import uvicorn
    # Use HTTPS in production
    ssl_keyfile = os.getenv("SSL_KEYFILE")
    ssl_certfile = os.getenv("SSL_CERTFILE")
    
    if ssl_keyfile and ssl_certfile:
        uvicorn.run(app, host="0.0.0.0", port=8000, ssl_keyfile=ssl_keyfile, ssl_certfile=ssl_certfile)
    else:
        uvicorn.run(app, host="0.0.0.0", port=8000)