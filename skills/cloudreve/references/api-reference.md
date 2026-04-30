# Cloudreve v4 API Reference

Official docs: https://docs.cloudreve.org/zh/api/overview
API playground: https://cloudrevev4.apifox.cn/

## Base URL

All API routes are prefixed with `/api/v4/`.

## Response Format

All responses are JSON. HTTP status is always 200; errors use the `code` field.

```json
{
  "data": ...,
  "code": 0,
  "msg": ""
}
```

- `code: 0` — success
- `code > 0` — error (see error codes below)

## Authentication

### Login (Password)

```
POST /api/v4/session/token
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "your-password"
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "user": {
      "id": "nGck",
      "email": "user@example.com",
      "nickname": "username",
      "status": "active",
      "group": { "id": "5lcE", "name": "Admin" }
    },
    "token": {
      "access_token": "eyJ...",
      "refresh_token": "eyJ...",
      "access_expires": "2026-03-30T22:56:42+08:00",
      "refresh_expires": "2026-04-13T21:56:42+08:00"
    }
  }
}
```

### Refresh Token

```
POST /api/v4/session/token/refresh
Content-Type: application/json

{
  "refresh_token": "eyJ..."
}
```

### OAuth (Recommended for third-party apps)

See: https://docs.cloudreve.org/zh/api/auth

## Storage

### Get Storage Capacity

```
GET /api/v4/user/capacity
Authorization: Bearer <token>
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "total": 1099511627776,
    "used": 61438
  }
}
```

## Files

### List / Browse

```
GET /api/v4/file?uri=<URL-encoded file URI>
Authorization: Bearer <token>
```

**File URI examples:**
- `cloudreve://my` — root directory
- `cloudreve://my/subfolder` — subdirectory
- `cloudreve://my?category=image` — filter by category
- `cloudreve://my?name=report&type=file` — search

**Response:**
```json
{
  "code": 0,
  "data": {
    "files": [
      {
        "type": 0,
        "id": "mNuG",
        "name": "test.md",
        "size": 1024,
        "path": "cloudreve://my/test.md",
        "created_at": "2026-03-30T06:49:43Z",
        "updated_at": "2026-03-30T06:49:43Z",
        "metadata": {},
        "capability": "w8edAQ==",
        "owned": true,
        "primary_entity": "5LTd"
      }
    ],
    "parent": { "type": 1, "id": "aRcd", "name": "" }
  }
}
```

- `type: 0` = file, `type: 1` = directory

### Upload

See: https://docs.cloudreve.org/zh/api/upload

**Step 1: Create Upload Session**

```
PUT /api/v4/file/upload
Authorization: Bearer <token>
Content-Type: application/json

{
  "uri": "cloudreve://my/filename.txt",
  "size": 12345
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "session_id": "a39b0f4d-...",
    "chunk_size": 26214400,
    "upload_urls": [],
    "credential": "",
    "expires": 1774967075,
    "storage_policy": {
      "id": "vec4",
      "name": "Default storage policy",
      "type": "local",
      "chunk_concurrency": 1
    },
    "uri": "cloudreve://my/filename.txt"
  }
}
```

**Step 2: Upload Chunks**

For local/remote storage policies (relay=true):

```
POST /api/v4/file/upload/<session_id>/<chunk_index>
Authorization: Bearer <token>
Content-Type: application/octet-stream

<binary data>
```

- Chunk index starts at 0
- Chunk size from session response
- For small files, single chunk (index 0) is sufficient

For S3-compatible: use pre-signed URLs from `upload_urls`.
For OneDrive: use byte-range uploads to `upload_urls`.

**Step 3: Complete Upload**

- Local/remote/Upyun: auto-completes after last chunk
- S3: call CompleteMultipartUpload, then callback
- OneDrive: call complete endpoint

### Download

**Step 1: Get Signed URL**

```
POST /api/v4/file/url
Authorization: Bearer <token>
Content-Type: application/json

{
  "uris": ["cloudreve://my/file.txt"]
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "urls": [
      {
        "url": "https://cloudreve.example.com/api/v4/file/content/...?sign=..."
      }
    ]
  }
}
```

**Step 2: Download**

```
GET <signed_url>
```

### Delete

```
DELETE /api/v4/file
Authorization: Bearer <token>
Content-Type: application/json

{
  "uris": ["cloudreve://my/file.txt"]
}
```

### Other Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v4/file/create` | POST | Create folder |
| `/api/v4/file/rename` | PUT | Rename file |
| `/api/v4/file/move` | PUT | Move file |
| `/api/v4/file/info` | GET | Get file info |
| `/api/v4/file/search` | POST | Search files |
| `/api/v4/file/events` | GET | SSE file change events |
| `/api/v4/file/metadata` | PUT | Update metadata |
| `/api/v4/file/version` | GET/DELETE | File versions |
| `/api/v4/file/lock` | PUT/DELETE | Lock/unlock file |
| `/api/v4/file/pin` | PUT/DELETE | Pin/unpin file |

## File URI Scheme

See: https://docs.cloudreve.org/zh/api/file-uri

```
cloudreve://[user@]host[/path][?query]
```

| Host | Description |
|------|-------------|
| `my` | Current user's files |
| `shared_with_me` | Files shared with me |
| `trash` | Recycle bin |
| `share` | Shared files |

**Query parameters (list only):**

| Parameter | Description |
|-----------|-------------|
| `name` | Search by filename (multiple: `name=a&name=b`) |
| `name_op_or` | Match any name keyword (default: all) |
| `case_folding` | Case-insensitive search |
| `category` | Preset: `image`, `video`, `audio`, `document` |
| `type` | Filter: `file` or `folder` |
| `meta_<key>` | Search by metadata (contains) |
| `exact_meta_<key>` | Search by metadata (exact) |
| `size_gte` / `size_lte` | Size range filter |
| `created_gte` / `created_lte` | Creation time range (Unix timestamp) |
| `updated_gte` / `updated_lte` | Update time range (Unix timestamp) |

## Error Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 401 | Not logged in |
| 403 | No permission |
| 40001 | Parameter error |
| 40002 | Upload failed |
| 40016 | Parent directory does not exist |
| 40020 | Invalid credentials |
| 40049 | File too large |
| 40051 | Insufficient user capacity |
| 40052 | Illegal object name |
| 40077 | Entity does not exist |
| 40081 | Batch operation not fully completed |

Full list: https://docs.cloudreve.org/zh/api/overview#error-codes
