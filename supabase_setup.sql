-- Create users table
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255),
    google_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_drives table
CREATE TABLE user_drives (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    drive_type VARCHAR(50) NOT NULL, -- 'personal' or 'shared'
    access_token TEXT,
    refresh_token TEXT,
    drive_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create files table
CREATE TABLE files (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_drive_id UUID REFERENCES user_drives(id) ON DELETE CASCADE,
    drive_file_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100),
    size BIGINT,
    folder_id VARCHAR(255),
    shared_link TEXT,
    permission_id VARCHAR(255),
    link_expires_at TIMESTAMP WITH TIME ZONE,
    shared_by UUID REFERENCES users(id),
    shared_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    revoked_by UUID REFERENCES users(id),
    expired_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_drives_user_id ON user_drives(user_id);
CREATE INDEX idx_files_user_drive_id ON files(user_drive_id);
CREATE INDEX idx_files_drive_file_id ON files(drive_file_id);
CREATE INDEX idx_files_shared_by ON files(shared_by);
CREATE INDEX idx_files_expires_at ON files(link_expires_at);