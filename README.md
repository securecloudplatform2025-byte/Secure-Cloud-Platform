# Secure Cloud Platform

A secure cloud platform for managing multiple cloud drives with Flutter frontend and FastAPI backend.

## Project Structure

```
Secure Cloud Platform/
├── backend/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── .env.example        # Environment variables template
├── frontend/
│   └── secure_cloud_platform/  # Flutter application
└── supabase_setup.sql      # Database schema
```

## Setup Instructions

### Backend Setup

1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Create `.env` file from `.env.example` and add your credentials:
   ```
   SUPABASE_URL=your-supabase-project-url
   SUPABASE_KEY=your-supabase-anon-key
   GOOGLE_CREDENTIALS_PATH=credentials.json
   GOOGLE_DRIVE_FOLDER_ID=root
   ```

4. Setup Google Drive API:
   - Create a Google Cloud Project
   - Enable Google Drive API
   - Create a Service Account (for shared drive)
   - Download credentials.json and place in backend folder
   - Share your Google Drive with the service account email (or use a specific folder ID)
   - Create OAuth 2.0 Client ID (for user drives)
   - Add redirect URI: http://localhost:8000/oauth/callback
   - Get Client ID and Client Secret for OAuth

5. Run the server:
   ```bash
   python main.py
   ```

### Frontend Setup

1. Navigate to Flutter project:
   ```bash
   cd frontend/secure_cloud_platform
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Supabase Setup

1. Create a new Supabase project
2. Run the SQL commands from `supabase_setup.sql` in the SQL editor
3. Get your project URL and anon key from Settings > API

## API Endpoints

### Authentication
- Authentication handled by Supabase Auth (client-side)
- Google OAuth integration via Supabase
- All endpoints require Supabase access token in Authorization header

### Shared Drive (15GB Google Drive)
- `POST /shared/upload` - Upload file to user's folder in shared drive (auto-creates folder)
- `GET /shared/download/{file_id}` - Download file from shared drive
- `DELETE /shared/delete/{file_id}` - Delete file from shared drive
- `POST /shared/share/{file_id}` - Generate public share link

### User Personal Drives (OAuth)
- `POST /user/connect-drive` - Connect personal Google Drive (OAuth)
- `GET /user/list-files/{drive_id}` - List files in user drive
- `POST /user/upload-file/{drive_id}` - Upload file to user's folder (auto-creates folder)
- `GET /user/download-file/{drive_id}/{file_id}` - Download file from user drive
- `DELETE /user/delete-file/{drive_id}/{file_id}` - Delete file from user drive
- `POST /user/share-file/{drive_id}/{file_id}` - Share file from user drive

### Legacy Endpoints (Placeholder)
- `POST /connect-drive` - Connect personal cloud drive
- `GET /list-files` - List files
- `POST /upload-file` - Upload file
- `GET /download-file/{file_id}` - Download file
- `DELETE /delete-file/{file_id}` - Delete file
- `POST /share-file/{file_id}` - Share file

## Features

- JWT Authentication with secure token management
- Google OAuth integration for personal drives
- Shared drive (15GB) with service account
- **Automatic user folder creation** - Creates individual folders for each user
- Personal drives (up to 4 per user) with OAuth
- File sharing with expiration and permissions
- Rate limiting and security middleware
- Encrypted token storage
- File name sanitization
- Access control verification
- HTTPS support
- Cross-platform Flutter app (mobile + web)
- Drag & drop file uploads
- Responsive design

## Security Features

- **Rate Limiting**: All endpoints have rate limits (5-60 requests/minute)
- **JWT Authentication**: Secure token-based authentication
- **Token Encryption**: Refresh tokens encrypted in database
- **File Sanitization**: Filenames sanitized to prevent attacks
- **Access Control**: User ownership verification for all operations
- **CORS Protection**: Restricted origins in production
- **Security Headers**: XSS, CSRF, and clickjacking protection
- **Request Filtering**: Suspicious request pattern detection
- **IP Blocking**: Automatic blocking of malicious IPs
- **File Size Limits**: 100MB upload limit
- **HTTPS Enforcement**: SSL/TLS support in production
- **Input Validation**: All inputs validated and sanitized# securecloudplatform
