# Nuvio Cloud API Reference

> **Version:** 1.1 · **Last Updated:** July 1, 2026
> **Base URL:** `https://api.nuvio.tv`

Public REST and RPC endpoints for third-party clients that integrate with Nuvio user data. The API is exposed through Supabase and supports authenticated operations for profiles, addons, plugins, library, watch progress, watch history, collections, and profile settings.

> **Documentation and API Use Notice**
> This documentation is part of the Nuvio open-source project and is provided under the same project license unless stated otherwise. Nuvio names, logos, branding, and access to the hosted Nuvio service are not granted by that license and may be subject to separate terms, trademark rules, or service restrictions.
>
> This document covers the supported public integration surface only. It is not a full inventory of every Supabase table, RPC, or internal app workflow in the production project. Private app, operational, and destructive account flows are intentionally excluded.

---

## Table of Contents

- [Getting Started](#getting-started)
  - [Base URLs](#base-urls)
  - [Publishable Key](#publishable-key)
  - [Authentication](#authentication-header)
  - [Making Requests](#making-requests)
  - [Error Handling](#error-handling)
  - [Rate Limits](#rate-limits)
- [Authentication Endpoints](#authentication-endpoints)
- [Profiles](#profiles)
- [Addons](#addons)
- [Plugins](#plugins)
- [Library](#library)
- [Watch Progress](#watch-progress)
- [Watch History](#watch-history)
- [Profile Settings](#profile-settings)
- [Home Catalog Settings](#home-catalog-settings)
- [Collections](#collections)
- [Avatars](#avatars)
- [Sync Overview](#sync-overview)
- [Health Check](#health-check)
- [Concepts](#concepts)
  - [Profile System](#profile-system)
  - [Sync Strategies](#sync-strategies)
  - [Incremental Sync](#incremental-sync)
  - [Progress Key Format](#progress-key-format)
- [Client Libraries](#client-libraries)
- [Complete RPC Reference](#complete-rpc-reference)
- [Changelog](#changelog)

---

## Getting Started

### Base URLs

| Service | URL |
|---|---|
| REST API | `https://api.nuvio.tv/rest/v1/` |
| Auth | `https://api.nuvio.tv/auth/v1/` |
| Edge Functions | `https://api.nuvio.tv/functions/v1/` |

### Publishable Key

For public integrations, use the Nuvio publishable key below. Most `auth/v1` and `rest/v1` requests require it.

```
apikey: sb_publishable_1Clq8rlTVACkdcZuqr6_AD__xUUC_EN
```

**Notes:**
- External developers need this key for normal client access. It is not discoverable unless Nuvio publishes it in documentation or another public config surface.
- Use the Supabase publishable key for public clients and public documentation.
- The legacy Supabase anon key is also public, but publishable keys are preferred for new integrations.
- Do not expose a service role key in client apps, browser code, mobile apps, or public docs.
- Use placeholders in sample code if you want to keep examples generic, but the real publishable key must still be available somewhere in the public docs or SDK setup instructions.

### Authentication Header

After signing in, you receive an `access_token`. Include it in all authenticated requests:

```
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

### Making Requests

The API uses two patterns:

**1. RPC calls** (recommended for all data sync operations):

```http
POST /rest/v1/rpc/<function_name>
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>

{
  "param1": "value1",
  "param2": "value2"
}
```

**2. Direct table queries** (for simple reads with filtering):

```http
GET /rest/v1/<table_name>?select=*&column=eq.value
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Direct table queries use the PostgREST query syntax.

### Error Handling

Errors follow standard HTTP status codes. The response body contains details:

```json
{
  "code": "PGRST202",
  "message": "Could not find the function ...",
  "details": null,
  "hint": null
}
```

| Status | Meaning |
|---|---|
| 200 | Success |
| 201 | Created |
| 204 | No content (void RPCs) |
| 400 | Bad request / invalid parameters |
| 401 | Missing or expired authentication |
| 403 | Forbidden (RLS policy violation) |
| 404 | Not found |
| 409 | Conflict (duplicate key) |
| 422 | Unprocessable entity |
| 429 | Rate limited |

### Rate Limits

The API is served by Supabase infrastructure. Standard Supabase rate limits apply. Avoid sending more than 100 requests per second per user. Batch operations using RPC functions where possible.

---

## Authentication Endpoints

### Sign Up (Email/Password)

```http
POST /auth/v1/signup
Content-Type: application/json
apikey: <publishable_key>
```

Request body:

```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

Response (200):

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "abc123...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "created_at": "2026-01-01T00:00:00Z"
  }
}
```

Two default metadata/subtitle integrations are automatically created for new users.

### Sign In (Email/Password)

```http
POST /auth/v1/token?grant_type=password
Content-Type: application/json
apikey: <publishable_key>
```

Request body:

```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

Response (200): Same shape as sign-up.

### Refresh Token

```http
POST /auth/v1/token?grant_type=refresh_token
Content-Type: application/json
apikey: <publishable_key>
```

Request body:

```json
{
  "refresh_token": "your_refresh_token"
}
```

Response (200): Returns new `access_token` and `refresh_token`.

### Sign Out

```http
POST /auth/v1/logout
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

### Get Current User

```http
GET /auth/v1/user
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Response (200):

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "created_at": "2026-01-01T00:00:00Z"
}
```

---

## Profiles

Current public Nuvio clients support up to **6 profiles**. Addons, plugins, library, watch progress, watch history, settings, and collections are scoped by `profile_id`.

For profile sync, the backend also supports a `p_client_max_profiles` argument so each client can declare the highest profile slot it understands. Use `6` for current public Nuvio clients. If this argument is omitted, the server keeps legacy 4-profile deletion behavior for backward compatibility.

### List Profiles

```http
POST /rest/v1/rpc/sync_pull_profiles
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

No request body required.

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_index": 1,
    "name": "Main",
    "avatar_color_hex": "#1E88E5",
    "uses_primary_addons": false,
    "uses_primary_plugins": false,
    "avatar_id": "avatar_cat_01",
    "avatar_url": null,
    "pin_enabled": false,
    "pin_locked_until": null,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `id` | uuid | Profile record ID |
| `user_id` | uuid | Owner user ID |
| `profile_index` | integer | 1–6, unique per user in the public client surface |
| `name` | string | Display name |
| `avatar_color_hex` | string | Hex color (e.g. `#1E88E5`) |
| `uses_primary_addons` | boolean | Whether this profile shares addons with profile 1 |
| `uses_primary_plugins` | boolean | Whether this profile shares plugins with profile 1 |
| `avatar_id` | string \| null | Reference to avatar catalog entry |
| `avatar_url` | string \| null | Custom profile avatar image URL |
| `pin_enabled` | boolean | Read-only lock state for clients that need to show locked profiles |
| `pin_locked_until` | timestamp \| null | Read-only lock expiry, if the profile is temporarily locked |
| `created_at` | timestamp | Creation time |
| `updated_at` | timestamp | Last update time |

### Update Profiles

Full replace within the declared client profile range — profiles not included in the array will be deleted for slots `1..p_client_max_profiles`.

```http
POST /rest/v1/rpc/sync_push_profiles
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_client_max_profiles": 6,
  "p_profiles": [
    {
      "profile_index": 1,
      "name": "Main",
      "avatar_color_hex": "#1E88E5",
      "uses_primary_addons": false,
      "uses_primary_plugins": false,
      "avatar_id": "avatar_cat_01",
      "avatar_url": null
    },
    {
      "profile_index": 2,
      "name": "Kids",
      "avatar_color_hex": "#FF5722",
      "uses_primary_addons": true,
      "uses_primary_plugins": true
    }
  ]
}
```

Top-level body fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `p_profiles` | array | Yes | Complete profile list for the declared profile range |
| `p_client_max_profiles` | integer | No | Highest profile slot this client manages. Use 6 for current public clients. Defaults to 4 when omitted. |

Profile object fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `profile_index` | integer | Yes | 1–6 in the public client surface |
| `name` | string | Yes | Display name |
| `avatar_color_hex` | string | No | Hex color code |
| `uses_primary_addons` | boolean | No | Share addons with profile 1 |
| `uses_primary_plugins` | boolean | No | Share plugins with profile 1 |
| `avatar_id` | string | No | Avatar catalog ID; existing value is kept if omitted or null and `avatar_url` is not provided |
| `avatar_url` | string \| null | No | Custom avatar image URL. When provided, it takes precedence over `avatar_id`; send `null` or `""` to clear it. |

> **Note:** PIN fields are never overwritten by this endpoint. PIN management is an app-specific Nuvio flow and is not part of this public integration surface.

**Response:** `204 No Content`

### Delete Profile Data

Deletes all data associated with a profile: addons, plugins, collections, watch progress, library, watched items, and the profile row itself.

```http
POST /rest/v1/rpc/sync_delete_profile_data
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 2
}
```

**Response:** `204 No Content`

---

## Addons

Addons are catalog, metadata, subtitle, or playback integration URLs associated with a user profile.

### List Addons

Using a direct table query:

```http
GET /rest/v1/addons?select=*&profile_id=eq.1&order=sort_order
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "url": "https://v3-cinemeta.strem.io",
    "name": "Cinemeta",
    "enabled": true,
    "sort_order": 0,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `id` | uuid | Record ID |
| `user_id` | uuid | Owner user ID |
| `profile_id` | integer | Profile index (1–6 in the public client surface) |
| `url` | string | Addon manifest URL |
| `name` | string \| null | Display name |
| `enabled` | boolean | Whether addon is active |
| `sort_order` | integer | Display order (0-based) |
| `created_at` | timestamp | Creation time |
| `updated_at` | timestamp | Last update time |

### Sync Addons (Push)

Full replace — addons not in the array will be deleted for the specified profile.

```http
POST /rest/v1/rpc/sync_push_addons
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_addons": [
    {
      "url": "https://catalog.example.com/manifest.json",
      "name": "Example Catalog",
      "enabled": true,
      "sort_order": 0
    },
    {
      "url": "https://metadata.example.com/manifest.json",
      "name": "Example Metadata",
      "enabled": true,
      "sort_order": 1
    }
  ]
}
```

Addon object fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `url` | string | Yes | Addon manifest URL |
| `name` | string | No | Display name |
| `enabled` | boolean | No | Default `true` |
| `sort_order` | integer | No | Display order, default 0 |

**Deduplication:** Addons are keyed by `md5(url)` per user per profile. A push only updates if `name`, `enabled`, or `sort_order` actually changed.

**Response:** `204 No Content`

---

## Plugins

Plugins are supplementary content source URLs with an optional repository classification.

### List Plugins

```http
GET /rest/v1/plugins?select=*&profile_id=eq.1&order=sort_order
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "url": "https://example.com/plugin",
    "name": "My Plugin",
    "enabled": true,
    "sort_order": 0,
    "repo_type": "remote",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `id` | uuid | Record ID |
| `user_id` | uuid | Owner user ID |
| `profile_id` | integer | Profile index (1–6 in the public client surface) |
| `url` | string | Plugin URL |
| `name` | string \| null | Display name |
| `enabled` | boolean | Whether plugin is active |
| `sort_order` | integer | Display order |
| `repo_type` | string \| null | Repository classification |
| `created_at` | timestamp | Creation time |
| `updated_at` | timestamp | Last update time |

### Sync Plugins (Push)

Full replace — plugins not in the array will be deleted for the specified profile.

```http
POST /rest/v1/rpc/sync_push_plugins
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_plugins": [
    {
      "url": "https://example.com/plugin",
      "name": "My Plugin",
      "enabled": true,
      "sort_order": 0,
      "repo_type": "remote"
    }
  ]
}
```

Plugin object fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `url` | string | Yes | Plugin URL |
| `name` | string | No | Display name |
| `enabled` | boolean | No | Default `true` |
| `sort_order` | integer | No | Display order, default 0 |
| `repo_type` | string | No | Repository classification |

**Response:** `204 No Content`

---

## Library

The library stores bookmarked / favorited content items per profile.

### Get Library

```http
POST /rest/v1/rpc/sync_pull_library
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_limit": 500,
  "p_offset": 0
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | 1 | Profile index |
| `p_limit` | integer | 500 | Max items per page |
| `p_offset` | integer | 0 | Pagination offset |

Results are ordered by `added_at DESC`.

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "content_id": "tmdb:550",
    "content_type": "movie",
    "name": "Fight Club",
    "poster": "https://image.tmdb.org/t/p/w500/...",
    "poster_shape": "POSTER",
    "background": "https://image.tmdb.org/t/p/original/...",
    "description": "An insomniac office worker...",
    "release_info": "1999",
    "imdb_rating": 8.8,
    "genres": ["Drama", "Thriller"],
    "addon_base_url": "https://v3-cinemeta.strem.io",
    "added_at": 1711600000000,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `content_id` | string | Content identifier (e.g. `tmdb:550`) |
| `content_type` | string | `movie` or `series` |
| `name` | string | Content title |
| `poster` | string \| null | Poster image URL |
| `poster_shape` | string | `POSTER`, `LANDSCAPE`, or `SQUARE` |
| `background` | string \| null | Background image URL |
| `description` | string \| null | Synopsis |
| `release_info` | string \| null | Year or year range |
| `imdb_rating` | float \| null | IMDb rating |
| `genres` | string[] | Genre list |
| `addon_base_url` | string \| null | Source addon URL |
| `added_at` | integer | Epoch milliseconds when added |

### Sync Library (Push)

Full replace — items not in the array will be deleted for the specified profile.

```http
POST /rest/v1/rpc/sync_push_library
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_items": [
    {
      "content_id": "tmdb:550",
      "content_type": "movie",
      "name": "Fight Club",
      "poster": "https://image.tmdb.org/t/p/w500/...",
      "poster_shape": "POSTER",
      "background": "https://image.tmdb.org/t/p/original/...",
      "description": "An insomniac office worker...",
      "release_info": "1999",
      "imdb_rating": 8.8,
      "genres": ["Drama", "Thriller"],
      "addon_base_url": "https://v3-cinemeta.strem.io",
      "added_at": 1711600000000
    }
  ]
}
```

Library item fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `content_id` | string | Yes | Content identifier |
| `content_type` | string | Yes | `movie` or `series` |
| `name` | string | No | Title |
| `poster` | string | No | Poster URL |
| `poster_shape` | string | No | Default `POSTER` |
| `background` | string | No | Background URL |
| `description` | string | No | Synopsis |
| `release_info` | string | No | Year |
| `imdb_rating` | float | No | IMDb rating |
| `genres` | string[] | No | Genre list |
| `addon_base_url` | string | No | Source addon |
| `added_at` | integer | No | Epoch milliseconds |

**Response:** `204 No Content`

---

## Watch Progress

Tracks playback position for "continue watching" functionality. Uses a **non-destructive merge strategy** — pushes upsert only and never delete entries not in the payload.

### Get Watch Progress

```http
POST /rest/v1/rpc/sync_pull_watch_progress
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_since_last_watched": 1711600000000,
  "p_limit": 200
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | 1 | Profile index |
| `p_since_last_watched` | integer | null | Optional epoch-millisecond cursor. When set, returns rows with `last_watched` greater than this value. |
| `p_limit` | integer | 200 | Optional row limit. Without `p_since_last_watched`, the server caps the result at 200 rows. |

Without `p_since_last_watched`, returns the latest progress entries for the profile, ordered by `last_watched DESC`. Use the delta endpoints below when you need delete events or a stable event cursor.

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "content_id": "tmdb:550",
    "content_type": "movie",
    "video_id": "tmdb:550",
    "season": null,
    "episode": null,
    "progress_key": "tmdb:550",
    "position": 3600000,
    "duration": 7920000,
    "last_watched": 1711600000000
  },
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "content_id": "tmdb:1396",
    "content_type": "series",
    "video_id": "tmdb:1396:1:1",
    "season": 1,
    "episode": 1,
    "progress_key": "tmdb:1396_s1e1",
    "position": 1800000,
    "duration": 3480000,
    "last_watched": 1711600000000
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `content_id` | string | Content identifier (e.g. `tmdb:550`) |
| `content_type` | string | `movie` or `series` |
| `video_id` | string | Specific playback item ID |
| `season` | integer \| null | Season number (series only) |
| `episode` | integer \| null | Episode number (series only) |
| `progress_key` | string | Unique key (see [Progress Key Format](#progress-key-format)) |
| `position` | integer | Playback position in milliseconds |
| `duration` | integer | Total duration in milliseconds |
| `last_watched` | integer | Epoch milliseconds of last playback |

### Get Watch Progress Delta

Returns upsert and delete events after a stored event cursor. Use this for incremental sync after a client has completed an initial snapshot pull.

```http
POST /rest/v1/rpc/sync_pull_watch_progress_delta
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_since_event_id": 12345,
  "p_limit": 1000
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | 1 | Profile index |
| `p_since_event_id` | integer | 0 | Return events with `event_id` greater than this value |
| `p_limit` | integer | 1000 | Max events to return, capped at 1000 |

Response (200):

```json
[
  {
    "event_id": 12346,
    "operation": "upsert",
    "progress_key": "tmdb:550",
    "content_id": "tmdb:550",
    "content_type": "movie",
    "video_id": "tmdb:550",
    "season": null,
    "episode": null,
    "position": 3600000,
    "duration": 7920000,
    "last_watched": 1711600000000
  },
  {
    "event_id": 12347,
    "operation": "delete",
    "progress_key": "tmdb:1396_s1e1",
    "content_id": "tmdb:1396",
    "content_type": "series",
    "video_id": "tmdb:1396:1:1",
    "season": 1,
    "episode": 1,
    "position": 1800000,
    "duration": 3480000,
    "last_watched": 1711600000000
  }
]
```

Apply events in ascending `event_id` order and store the highest `event_id` you processed.

### Get Watch Progress Delta Cursor

Returns the current maximum watch-progress event ID for the profile. After a full snapshot sync, call this and store the returned value as the next `p_since_event_id`.

```http
POST /rest/v1/rpc/sync_get_watch_progress_delta_cursor
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1
}
```

Response (200):

```json
12347
```

### Sync Watch Progress (Push)

Non-destructive merge — upserts only; does not delete missing entries.

```http
POST /rest/v1/rpc/sync_push_watch_progress
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_entries": [
    {
      "content_id": "tmdb:550",
      "content_type": "movie",
      "video_id": "tmdb:550",
      "position": 3600000,
      "duration": 7920000,
      "last_watched": 1711600000000
    },
    {
      "content_id": "tmdb:1396",
      "content_type": "series",
      "video_id": "tmdb:1396:1:1",
      "season": 1,
      "episode": 1,
      "position": 1800000,
      "duration": 3480000,
      "last_watched": 1711600000000
    }
  ]
}
```

Watch progress entry fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `content_id` | string | Yes | Content identifier |
| `content_type` | string | Yes | `movie` or `series` |
| `video_id` | string | Yes | Playback item identifier |
| `season` | integer | No | Season number (for series) |
| `episode` | integer | No | Episode number (for series) |
| `position` | integer | Yes | Playback position in ms |
| `duration` | integer | Yes | Total duration in ms |
| `last_watched` | integer | Yes | Epoch milliseconds |

**Completion handling:** When an entry has `duration >= 60000` and `position` at least 90% of `duration`, the server also upserts a matching watched-history item. Tiny progress changes may be ignored server-side to reduce write volume.

**Response:** `204 No Content`

### Delete Watch Progress (Single)

```http
POST /rest/v1/rpc/sync_delete_watch_progress
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_progress_key": "tmdb:550",
  "p_profile_id": 1
}
```

**Response:** `204 No Content`

### Delete Watch Progress (Batch)

```http
POST /rest/v1/rpc/sync_delete_watch_progress
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_keys": ["tmdb:550", "tmdb:1396_s1e1"],
  "p_profile_id": 1
}
```

**Response:** `204 No Content`

---

## Watch History

Records of content that has been watched. Uses a **non-destructive merge strategy** for pushes.

### Get Watch History

```http
POST /rest/v1/rpc/sync_pull_watched_items
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_page": 1,
  "p_page_size": 500
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | 1 | Profile index |
| `p_page` | integer | 1 | Page number (1-indexed) |
| `p_page_size` | integer | 100000 | Items per page |

Results are ordered by `watched_at DESC`.

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "content_id": "tmdb:550",
    "content_type": "movie",
    "title": "Fight Club",
    "season": null,
    "episode": null,
    "watched_at": 1711600000000,
    "created_at": "2026-01-01T00:00:00Z"
  }
]
```

Response fields:

| Field | Type | Description |
|---|---|---|
| `content_id` | string | Content identifier |
| `content_type` | string | `movie` or `series` |
| `title` | string | Content title |
| `season` | integer \| null | Season number (series only) |
| `episode` | integer \| null | Episode number (series only) |
| `watched_at` | integer | Epoch milliseconds |

### Get Watch History Delta

Returns watched-history upsert and delete events after a stored event cursor. Use this for incremental sync after a client has completed an initial snapshot pull.

```http
POST /rest/v1/rpc/sync_pull_watched_items_delta
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_since_event_id": 98765,
  "p_limit": 1000
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | 1 | Profile index |
| `p_since_event_id` | integer | 0 | Return events with `event_id` greater than this value |
| `p_limit` | integer | 1000 | Max events to return, capped at 1000 |

Response (200):

```json
[
  {
    "event_id": 98766,
    "operation": "upsert",
    "content_id": "tmdb:550",
    "content_type": "movie",
    "title": "Fight Club",
    "season": null,
    "episode": null,
    "watched_at": 1711600000000
  },
  {
    "event_id": 98767,
    "operation": "delete",
    "content_id": "tmdb:1396",
    "content_type": "series",
    "title": "Breaking Bad S01E01",
    "season": 1,
    "episode": 1,
    "watched_at": 1711600000000
  }
]
```

Apply events in ascending `event_id` order and store the highest `event_id` you processed.

### Get Watch History Delta Cursor

Returns the current maximum watched-history event ID for the profile. After a full snapshot sync, call this and store the returned value as the next `p_since_event_id`.

```http
POST /rest/v1/rpc/sync_get_watched_items_delta_cursor
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1
}
```

Response (200):

```json
98767
```

### Sync Watch History (Push)

Non-destructive merge — upserts only.

```http
POST /rest/v1/rpc/sync_push_watched_items
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_items": [
    {
      "content_id": "tmdb:550",
      "content_type": "movie",
      "title": "Fight Club",
      "watched_at": 1711600000000
    },
    {
      "content_id": "tmdb:1396",
      "content_type": "series",
      "title": "Breaking Bad S01E01",
      "season": 1,
      "episode": 1,
      "watched_at": 1711600000000
    }
  ]
}
```

Watched item fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `content_id` | string | Yes | Content identifier |
| `content_type` | string | Yes | `movie` or `series` |
| `title` | string | No | Title |
| `season` | integer | No | Season number |
| `episode` | integer | No | Episode number |
| `watched_at` | integer | Yes | Epoch milliseconds |

**Response:** `204 No Content`

### Delete Watch History

```http
POST /rest/v1/rpc/sync_delete_watched_items
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_keys": [
    { "content_id": "tmdb:550" },
    { "content_id": "tmdb:1396", "season": 1, "episode": 1 }
  ]
}
```

Key object fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `content_id` | string | Yes | Content identifier |
| `season` | integer | No | Required for series episodes |
| `episode` | integer | No | Required for series episodes |

**Response:** `204 No Content`

---

## Profile Settings

A generic JSON key-value store for per-profile settings (theme, player preferences, UI options, etc.). Settings are platform-aware when `p_platform` is supplied.

### Get Settings

```http
POST /rest/v1/rpc/sync_pull_profile_settings_blob
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_platform": "tv"
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | Required | Profile index |
| `p_platform` | string | `tv` | Optional platform namespace. Recommended for new clients. |

Response (200):

```json
[
  {
    "profile_id": 1,
    "settings_json": {
      "theme": "dark",
      "player_quality": "auto",
      "subtitle_language": "en",
      "auto_play_next": true
    },
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

The `settings_json` field is an arbitrary JSON object. The server does not enforce any particular schema — your application defines the structure.

### Update Settings

Atomic upsert — fully replaces the settings blob for the profile.

```http
POST /rest/v1/rpc/sync_push_profile_settings_blob
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_platform": "tv",
  "p_settings_json": {
    "theme": "dark",
    "player_quality": "auto",
    "subtitle_language": "en",
    "auto_play_next": true
  }
}
```

**Response:** `204 No Content`

---

## Home Catalog Settings

Stores per-profile home catalog configuration as a JSON blob. This is separate from the general profile settings blob so clients can sync home-layout/catalog preferences independently.

### Get Home Catalog Settings

```http
POST /rest/v1/rpc/sync_pull_home_catalog_settings
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_platform": "tv"
}
```

Response (200):

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "profile_id": 1,
    "platform": "tv",
    "settings_json": {
      "rows": [],
      "hidden_catalogs": []
    },
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

The `settings_json` payload is application-defined JSON.

### Update Home Catalog Settings

```http
POST /rest/v1/rpc/sync_push_home_catalog_settings
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_platform": "tv",
  "p_settings_json": {
    "rows": [],
    "hidden_catalogs": []
  }
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `p_profile_id` | integer | Required | Profile index |
| `p_platform` | string | `tv` | Optional platform namespace. Recommended for new clients. |
| `p_settings_json` | object | Required | Full home catalog settings payload |

**Response:** `204 No Content`

---

## Collections

Custom curated collections of content, stored as a JSON blob per profile.

### Get Collections

```http
POST /rest/v1/rpc/sync_pull_collections
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1
}
```

Response (200):

```json
[
  {
    "profile_id": 1,
    "collections_json": [
      {
        "id": "collection-1",
        "title": "Weekend Picks",
        "backdropImageUrl": "https://cdn.example.com/backdrops/weekend.jpg",
        "pinToTop": true,
        "viewMode": "TABBED_GRID",
        "showAllTab": true,
        "folders": [
          {
            "id": "folder-1",
            "title": "Sci-Fi",
            "coverImageUrl": "https://cdn.example.com/folders/scifi.jpg",
            "coverEmoji": "🚀",
            "tileShape": "LANDSCAPE",
            "hideTitle": false,
            "catalogSources": [
              {
                "addonId": "com.stremio.cinemeta",
                "type": "movie",
                "catalogId": "top"
              }
            ]
          }
        ]
      }
    ],
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

Collection JSON structure:

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique collection ID |
| `title` | string | Collection name |
| `backdropImageUrl` | string | Optional backdrop image |
| `pinToTop` | boolean | Pin to top of home screen |
| `viewMode` | string | `TABBED_GRID`, `ROWS`, or `FOLLOW_LAYOUT` |
| `showAllTab` | boolean | Show "All" tab in tabbed view |
| `folders` | array | Array of folder objects |

Folder object:

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique folder ID |
| `title` | string | Folder name |
| `coverImageUrl` | string | Optional cover image |
| `coverEmoji` | string | Optional emoji icon |
| `tileShape` | string | `POSTER`, `LANDSCAPE`, or `SQUARE` |
| `hideTitle` | boolean | Hide the tile title text |
| `catalogSources` | array | Array of catalog source references |

Catalog source:

| Field | Type | Description |
|---|---|---|
| `addonId` | string | Addon identifier |
| `type` | string | Content type (e.g. `movie`, `series`) |
| `catalogId` | string | Catalog identifier |

### Update Collections

Full replace — overwrites the entire collections blob for the profile. Push an empty array (`[]`) to clear.

```http
POST /rest/v1/rpc/sync_push_collections
Content-Type: application/json
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Request body:

```json
{
  "p_profile_id": 1,
  "p_collections_json": [
    {
      "id": "collection-1",
      "title": "Weekend Picks",
      "viewMode": "TABBED_GRID",
      "folders": []
    }
  ]
}
```

**Response:** `204 No Content`

---

## Avatars

A catalog of available profile avatars. Clients should also support `avatar_color_hex` and `avatar_url` from profile rows, because custom avatar URLs can be used without an avatar catalog entry.

### List Avatars

No authentication required.

```http
POST /rest/v1/rpc/get_avatar_catalog
apikey: <publishable_key>
```

Response (200):

```json
[
  {
    "id": "avatar_cat_01",
    "display_name": "Cool Cat",
    "storage_path": "avatars/avatar_cat_01.png",
    "category": "character",
    "sort_order": 0,
    "is_active": true,
    "bg_color": "#FFB74D",
    "created_at": "2026-01-01T00:00:00Z"
  }
]
```

The response may be an empty array if no catalog avatars are currently published.

Response fields:

| Field | Type | Description |
|---|---|---|
| `id` | string | Avatar ID for use in profile `avatar_id` |
| `display_name` | string | Human-readable name |
| `storage_path` | string | Storage path for the image |
| `category` | string | Category (e.g. `character`) |
| `sort_order` | integer | Display order |
| `is_active` | boolean | Whether available for selection |
| `bg_color` | string \| null | Suggested background color |

---

## Sync Overview

Returns a summary of core sync data counts per profile — useful for dashboards and status displays.

```http
POST /rest/v1/rpc/get_sync_overview
Authorization: Bearer <access_token>
apikey: <publishable_key>
```

Response (200):

```json
{
  "addons": { "1": 5, "2": 3 },
  "plugins": { "1": 2 },
  "library_items": { "1": 42, "2": 10 },
  "watch_progress": { "1": 150, "2": 30 },
  "watched_items": { "1": 200, "2": 50 },
  "profiles": {
    "1": { "name": "Main", "color": "#1E88E5" },
    "2": { "name": "Kids", "color": "#FF5722" }
  }
}
```

Each key in the data objects is a profile index. The `profiles` entry includes the display name and color. This overview currently counts addons, plugins, library items, watch progress, watched items, and profiles only; it does not include collections, profile settings, or home catalog settings.

---

## Health Check

Check the API and database health status. No authentication required.

```http
GET /functions/v1/health-check
```

Response (200):

```json
{
  "status": "healthy",
  "database": "connected",
  "latency_ms": 45,
  "timestamp": "2026-04-07T12:00:00.000Z"
}
```

| Status | Meaning |
|---|---|
| `healthy` | Everything operational |
| `slow` | Database responding slowly |
| `degraded` | Partial issues |
| `down` | Database unreachable |

You can also use the lightweight RPC ping:

```http
POST /rest/v1/rpc/health_ping
apikey: <publishable_key>
```

Returns `true` if the database is reachable.

---

## Concepts

### Profile System

Current public Nuvio clients support up to 6 profiles (indexed 1–6). Every data resource (addons, plugins, library, watch progress, watch history, settings, collections) is scoped to a profile via the `profile_id` parameter.

Profiles can optionally share addons or plugins with profile 1 by setting `uses_primary_addons` / `uses_primary_plugins` to `true`.

### Sync Strategies

The API uses two distinct sync strategies:

| Strategy | Used By | Behavior |
|---|---|---|
| **Full replace** | Addons, Plugins, Library, Profiles, Collections | The payload represents the complete current state. Items not present in the push payload are deleted server-side. Profile replacement is scoped to `1..p_client_max_profiles`. |
| **Atomic blob upsert** | Profile Settings, Home Catalog Settings | The JSON payload fully replaces one `(user, profile, platform)` blob. |
| **Non-destructive merge** | Watch Progress, Watch History | Push only upserts records. Existing records not in the payload are preserved. Use explicit delete endpoints to remove individual records. |

> **Caution with full-replace endpoints:** Always send the complete list when pushing addons, plugins, library items, profiles, or collections. Sending a partial list will delete everything not included.

### Incremental Sync

Watch progress and watch history support event-cursor delta endpoints. A typical client flow is:

1. Pull the full snapshot.
2. Call the matching `sync_get_*_delta_cursor` RPC and store the returned event ID.
3. Later, call the matching `sync_pull_*_delta` RPC with the stored event ID.
4. Apply events in ascending `event_id` order and persist the highest processed event ID.

Use snapshot pulls for bootstrap or recovery. Use delta pulls for ongoing sync, especially when a client needs to observe deletions.

### Progress Key Format

Watch progress entries are deduplicated by a `progress_key`:

| Content Type | Format | Example |
|---|---|---|
| Movie | `{content_id}` | `tmdb:550` |
| Series episode | `{content_id}_s{season}e{episode}` | `tmdb:1396_s1e1` |

The server auto-corrects progress keys via a trigger, so you can rely on `content_id`, `season`, and `episode` fields — the progress key is computed automatically.

---

## Client Libraries

The API is exposed through Supabase, so any Supabase client library can call it:

| Language | Library |
|---|---|
| JavaScript/TypeScript | `@supabase/supabase-js` |
| Python | `supabase-py` |
| Kotlin | `supabase-kt` |
| Swift | `supabase-swift` |
| Dart/Flutter | `supabase-flutter` |
| C# | `supabase-csharp` |

> **For the tvOS migration:** `supabase-swift` is the relevant client library — same package family already used in the mobile app's `AuthConfig.swift`.

### Quick Start (JavaScript)

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://api.nuvio.tv',
  '<publishable_key>'
)

// Sign in
const { data: auth } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
})

// Get addons for profile 1
const { data: addons } = await supabase
  .from('addons')
  .select('*')
  .eq('profile_id', 1)
  .order('sort_order')

// Push addons
await supabase.rpc('sync_push_addons', {
  p_profile_id: 1,
  p_addons: [
    { url: 'https://v3-cinemeta.strem.io', name: 'Cinemeta', enabled: true, sort_order: 0 }
  ]
})

// Get library
const { data: library } = await supabase.rpc('sync_pull_library', {
  p_profile_id: 1,
  p_limit: 500,
  p_offset: 0
})

// Get watch progress
const { data: progress } = await supabase.rpc('sync_pull_watch_progress', {
  p_profile_id: 1
})

// Get sync overview
const { data: overview } = await supabase.rpc('get_sync_overview')
```

### Quick Start (Python)

```python
from supabase import create_client

supabase = create_client(
    "https://api.nuvio.tv",
    "<publishable_key>"
)

# Sign in
auth = supabase.auth.sign_in_with_password({
    "email": "user@example.com",
    "password": "password"
})

# Get addons
addons = supabase.table("addons") \
    .select("*") \
    .eq("profile_id", 1) \
    .order("sort_order") \
    .execute()

# Push watch progress
supabase.rpc("sync_push_watch_progress", {
    "p_profile_id": 1,
    "p_entries": [
        {
            "content_id": "tmdb:550",
            "content_type": "movie",
            "video_id": "tmdb:550",
            "position": 3600000,
            "duration": 7920000,
            "last_watched": 1711600000000
        }
    ]
}).execute()
```

### Quick Start (cURL)

```bash
# Sign in
curl -X POST 'https://api.nuvio.tv/auth/v1/token?grant_type=password' \
  -H 'apikey: <publishable_key>' \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"password"}'

# Get addons
curl 'https://api.nuvio.tv/rest/v1/addons?select=*&profile_id=eq.1&order=sort_order' \
  -H 'Authorization: Bearer <access_token>' \
  -H 'apikey: <publishable_key>'

# Push addons via RPC
curl -X POST 'https://api.nuvio.tv/rest/v1/rpc/sync_push_addons' \
  -H 'Authorization: Bearer <access_token>' \
  -H 'apikey: <publishable_key>' \
  -H 'Content-Type: application/json' \
  -d '{
    "p_profile_id": 1,
    "p_addons": [
      {"url":"https://v3-cinemeta.strem.io","name":"Cinemeta","enabled":true,"sort_order":0}
    ]
  }'

# Health check (no auth needed)
curl 'https://api.nuvio.tv/functions/v1/health-check'
```

---

## Complete RPC Reference

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `rpc/sync_pull_profiles` | POST | Yes | List all profiles |
| `rpc/sync_push_profiles` | POST | Yes | Full replace profiles within the declared client profile range |
| `rpc/sync_delete_profile_data` | POST | Yes | Delete all profile data |
| `rpc/sync_push_addons` | POST | Yes | Full replace addons |
| `rpc/sync_push_plugins` | POST | Yes | Full replace plugins |
| `rpc/sync_pull_library` | POST | Yes | Paginated library pull |
| `rpc/sync_push_library` | POST | Yes | Full replace library |
| `rpc/sync_pull_watch_progress` | POST | Yes | Latest or timestamp-filtered watch progress |
| `rpc/sync_pull_watch_progress_delta` | POST | Yes | Incremental progress events |
| `rpc/sync_get_watch_progress_delta_cursor` | POST | Yes | Current progress event cursor |
| `rpc/sync_push_watch_progress` | POST | Yes | Upsert watch progress |
| `rpc/sync_delete_watch_progress` | POST | Yes | Delete progress entries |
| `rpc/sync_pull_watched_items` | POST | Yes | Paginated history pull |
| `rpc/sync_pull_watched_items_delta` | POST | Yes | Incremental history events |
| `rpc/sync_get_watched_items_delta_cursor` | POST | Yes | Current history event cursor |
| `rpc/sync_push_watched_items` | POST | Yes | Upsert watch history |
| `rpc/sync_delete_watched_items` | POST | Yes | Delete history entries |
| `rpc/sync_pull_profile_settings_blob` | POST | Yes | Get profile settings |
| `rpc/sync_push_profile_settings_blob` | POST | Yes | Update profile settings |
| `rpc/sync_pull_home_catalog_settings` | POST | Yes | Get home catalog settings |
| `rpc/sync_push_home_catalog_settings` | POST | Yes | Update home catalog settings |
| `rpc/sync_pull_collections` | POST | Yes | Get collections |
| `rpc/sync_push_collections` | POST | Yes | Update collections |
| `rpc/get_avatar_catalog` | POST | No | List available avatars |
| `rpc/get_sync_overview` | POST | Yes | Data count summary |
| `rpc/health_ping` | POST | No | Database ping |
| `functions/v1/health-check` | GET | No | Full health check |

---

## Changelog

**v1.1 — June 11, 2026**
- Updated the public documentation date and clarified that this page is a supported public API allowlist, not a full Supabase RPC inventory
- Updated profile docs for 6-profile public clients, `p_client_max_profiles`, `avatar_url`, and read-only lock-state fields
- Documented platform-aware profile settings and home catalog settings sync
- Updated watch progress pull behavior and added progress/history delta cursor endpoints for incremental sync
- Corrected watched-completion behavior and added caveats for sync overview and avatar catalog responses

**v1.0 — April 2026**
- Initial public API documentation release
- Covers the public integration surface for auth, profiles, addons, plugins, library, watch progress, watch history, collections, settings, overview, and health checks
