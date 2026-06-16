# Cloudflare R2 Integration

This document covers how the OTT platform stores and serves media on
Cloudflare R2: the bucket layout, the upload/streaming APIs, the security
model, and a step-by-step deployment guide.

> TL;DR: one **private** bucket. Every read and write goes through a
> **short-lived presigned URL** minted server-side in a Supabase Edge
> Function. R2 credentials live only in Supabase function secrets — never
> in the mobile app, the browser, or the Next.js host.

---

## 1. Architecture

```
                 ┌──────────────────────────────────────────┐
                 │            Supabase Edge Functions          │
  Admin / App    │  issue-upload-url     (admin: presign PUT)  │
  (JWT only) ───▶│  issue-playback-license (presign GET ×N)    │──▶ signs with
                 │  issue-audio-license    (presign GET)       │    R2 keys
                 └──────────────────────────────────────────┘    (secrets)
                          │  returns presigned URL                     │
                          ▼                                            ▼
              client uploads/streams DIRECTLY  ───────────▶  ┌──────────────────┐
              to the presigned URL (bytes never              │  Private R2      │
              transit our servers)                           │  bucket          │
                                                             └──────────────────┘
```

- **content_assets** (Postgres) is the single source of truth mapping a
  piece of content → an R2 object key. Signing functions read it; the
  upload API writes it.
- **entitlements** (Postgres) gates premium playback.

---

## 2. Bucket structure

A single private bucket (default name `ott-content`). Object keys are
namespaced by content kind and id so a piece of content's assets are
co-located and easy to lifecycle/delete:

```
<bucket>/
  video/
    <video_id>/
      video_mp4.mp4            # progressive source / MVP single-file
      video_hls/               # (post-transcode) HLS ladder
        master.m3u8
        720p/playlist.m3u8 + segments
        1080p/...
      poster.jpg
      thumbnail.jpg
      trailer.mp4
      subtitle.en.vtt
  audio/
    <audio_id>/
      audio_mp3.mp3            # progressive source / MVP single-file
      audio_hls/
        master.m3u8 + segments
      poster.jpg
```

The key for each asset is produced by `buildAssetKey()` in
`supabase/functions/_shared/r2.ts`:
`"<contentType>/<contentId>/<assetType>.<ext>"`. The full key is stored in
`content_assets.r2_path` (unique).

---

## 3. APIs

All three are Supabase Edge Functions. They require a Supabase
`Authorization: Bearer <jwt>` header.

### 3.1 `issue-upload-url` — Secure Uploads (admin only)

**Action `presign`** (default):

```jsonc
// POST /functions/v1/issue-upload-url
{
  "content_type": "video",          // "video" | "audio"
  "content_id": "<uuid>",
  "asset_type": "video_mp4",        // see content_assets check constraint
  "file_ext": "mp4",
  "file_content_type": "video/mp4", // pinned into the signature
  "resolution": "1080p",            // optional
  "bitrate": 5000000                 // optional
}
// → 200
{
  "asset_id": "<uuid>",
  "r2_path": "video/<id>/video_mp4.mp4",
  "upload_url": "https://<acct>.r2.cloudflarestorage.com/...&X-Amz-...",
  "required_content_type": "video/mp4",
  "expires_in_seconds": 900
}
```

The client then `PUT`s the file straight to `upload_url` with header
`Content-Type: <required_content_type>` (must match exactly — it's signed).

**Action `complete`** (after the PUT returns 200):

```jsonc
{ "action": "complete", "asset_id": "<uuid>", "bytes": 123456789 }
// → { "ok": true, "asset_id": "<uuid>" }
```

This flips the asset to `status = 'ready'`, making it eligible for
playback. (A real transcode pipeline would call `complete` from its
finished-job webhook instead.)

### 3.2 `issue-playback-license` — Video Streaming

`POST { "video_id": "<uuid>" }` with `X-Device-Id` header. Validates
device lock + entitlement, then returns one presigned GET URL per ready
rendition:

```jsonc
{
  "video_id": "<uuid>",
  "qualities": [{ "label": "1080p", "bitrate": 5000000, "url": "https://…" }],
  "resume_position_seconds": 0,
  "expires_in_seconds": 600
}
```

### 3.3 `issue-audio-license` — Audio Streaming

`POST { "audio_id": "<uuid>" }` with `X-Device-Id`. Returns a single
presigned GET URL (audio is single-bitrate):

```jsonc
{ "audio_id": "<uuid>", "url": "https://…", "resume_position_seconds": 0, "expires_in_seconds": 600 }
```

---

## 4. Security rules

| Control | How |
|---|---|
| **Private bucket** | No public access, no `r2.dev` public URL, no custom-domain public binding. The only way in/out is a presigned URL. |
| **Credential isolation** | `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` are stored only as Supabase **function secrets**. They are never shipped to the app, the browser, or committed to git. |
| **Short-lived URLs** | Playback GET URLs expire in **600 s**; upload PUT URLs in **900 s** (`_shared/r2.ts`). A leaked URL is useless after that. |
| **Upload is admin-only** | `issue-upload-url` looks up the caller's `profiles.role` and rejects non-`admin`/`content_manager` with 403. |
| **Content-Type pinning** | Upload PUTs are signed with the declared `Content-Type`; the client must send the same value or R2 rejects the request. |
| **Device lock on playback** | License functions require the caller's `X-Device-Id` to match the account's active device row. |
| **Entitlement check** | Premium content requires a non-expired `entitlements` row before any URL is signed. |
| **RLS** | `content_assets` is readable only when `status='ready'` (or admin); `entitlements` only by their owner (or admin); writes admin/service-role only. |
| **Scoped R2 token** | Use an R2 API token scoped to **Object Read & Write on this one bucket** — not an account-wide token. |
| **CORS** | The bucket allows `PUT`/`GET` from the admin/web origins only (see §5.4). Native mobile doesn't need bucket CORS. |

---

## 5. Deployment guide

### 5.1 Create the bucket

1. Cloudflare dashboard → **R2** → **Create bucket** → name `ott-content`.
2. Leave it **private** (do not enable the public `r2.dev` URL).
3. Note your **Account ID** (R2 → Overview, right sidebar).

### 5.2 Create a scoped API token

1. R2 → **Manage R2 API Tokens** → **Create API token**.
2. Permissions: **Object Read & Write**.
3. Scope: **Apply to specific buckets only** → `ott-content`.
4. Save the **Access Key ID** and **Secret Access Key** (shown once).

### 5.3 Set Supabase function secrets

```bash
supabase secrets set \
  R2_ACCOUNT_ID=<account-id> \
  R2_ACCESS_KEY_ID=<access-key-id> \
  R2_SECRET_ACCESS_KEY=<secret-access-key> \
  R2_BUCKET=ott-content
# SUPABASE_URL / SUPABASE_ANON_KEY are provided to functions automatically.
```

### 5.4 Configure bucket CORS (for browser uploads/streaming)

R2 → bucket → **Settings** → **CORS policy**:

```json
[
  {
    "AllowedOrigins": ["https://admin.yourdomain.com", "http://localhost:3000"],
    "AllowedMethods": ["GET", "PUT"],
    "AllowedHeaders": ["content-type"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

### 5.5 Apply migrations

```bash
supabase db push          # applies up to 20260616000014_content_assets_and_entitlements
```

### 5.6 Deploy the functions

```bash
supabase functions deploy issue-upload-url
supabase functions deploy issue-playback-license
supabase functions deploy issue-audio-license
```

### 5.7 Smoke test

```bash
# As an admin JWT — presign an upload:
curl -s -X POST "$SUPABASE_URL/functions/v1/issue-upload-url" \
  -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" \
  -d '{"content_type":"video","content_id":"<uuid>","asset_type":"video_mp4","file_ext":"mp4","file_content_type":"video/mp4"}'

# Upload the file to the returned upload_url:
curl -X PUT "<upload_url>" -H "Content-Type: video/mp4" --data-binary @movie.mp4

# Mark it ready:
curl -s -X POST "$SUPABASE_URL/functions/v1/issue-upload-url" \
  -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" \
  -d '{"action":"complete","asset_id":"<asset_id>"}'

# As a user JWT on the active device — get a playback license:
curl -s -X POST "$SUPABASE_URL/functions/v1/issue-playback-license" \
  -H "Authorization: Bearer $USER_JWT" -H "X-Device-Id: <device-uuid>" \
  -H "Content-Type: application/json" -d '{"video_id":"<uuid>"}'
```

---

## 6. Client integration notes

- **Flutter** (`mobile_app`): `player_remote_datasource.dart` and
  `audio_remote_datasource.dart` already call the license functions via
  `functions.invoke(...)` with the `X-Device-Id` header. No change needed
  for streaming.
- **Admin** (`admin`): the upload flow can either keep the Next.js
  server-action presign (R2 keys on the Next host) **or** switch to calling
  `issue-upload-url` (R2 keys only in Supabase — recommended). To switch,
  replace the body of `presignContentUpload`/`attachUpload` in
  `src/app/actions/content.ts` with a `fetch` to the edge function using
  the admin's access token. The request/response contracts already match
  (`upload_url`, `r2_path`, then `complete`).
- **Offline downloads**: the secure-download system reuses the same
  playback license URLs to fetch encrypted bytes — no R2-specific change.
