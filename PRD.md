# PostInTime

## Product Requirements Document

**Product:** PostInTime  
**Document Version:** 1.0  
**Date:** August 2026  
**Status:** Initial Product Specification  
**Architecture:** Modular Monolith  
**Frontend:** React + TypeScript + Vite  
**Backend:** Spring Boot + Java  
**Database:** PostgreSQL  

---

# 1. Executive Summary

PostInTime is a channel-centric content management and social publishing application.

The product provides a single workspace where a user can:

- Create and manage multiple content channels.
- Store posts containing titles, captions, and media.
- Configure social-media accounts belonging to each channel.
- Select one or more social accounts as publishing targets for a post.
- Publish content manually during the MVP.
- Track publication status independently for every social account.
- Eventually connect social-media APIs and publish automatically without redesigning the core application.

The first release intentionally focuses on **content organization and manual publishing**. API-based publishing, OAuth, scheduling, analytics, and platform-specific content variations are future capabilities.

The fundamental domain model is:

```text
User
 └── Channel
      ├── Posts
      │    └── Post Targets
      └── Social Accounts
```

A **Channel** is the primary organizational boundary. For example, a user may have:

```text
Tech
 ├── Posts
 ├── LinkedIn
 ├── Instagram
 └── WhatsApp

Gaming
 ├── Posts
 ├── YouTube
 ├── Instagram
 └── WhatsApp
```

The same social-media platform can therefore be configured independently for different channels.

---

# 2. Product Vision

PostInTime should become a personal command center for managing content across multiple channels and social identities.

The long-term workflow is:

```text
Create Content
      ↓
Choose Channel
      ↓
Choose Social Destinations
      ↓
Prepare / Customize Content
      ↓
Publish
      ↓
Track Publication
      ↓
Analyze Results
```

The MVP simplifies the publishing step:

```text
Create Content
      ↓
Choose Channel
      ↓
Choose Social Destinations
      ↓
Copy Caption + Access Media + Open Destination
      ↓
Publish Manually
      ↓
Mark as Published
```

The architecture must ensure that replacing the manual publishing step with API publishing later does not require redesigning posts, channels, or the dashboard.

---

# 3. Product Goals

## 3.1 Primary Goals

1. Provide a clean channel-centric content management system.
2. Store reusable post content centrally.
3. Keep social accounts isolated by channel.
4. Allow one post to target multiple social accounts.
5. Track publication status independently for every target.
6. Make manual publishing fast and convenient.
7. Establish a clean abstraction for future API publishing.
8. Support multiple channels for one user.
9. Keep the application simple enough for personal use.
10. Preserve a straightforward path toward multi-user SaaS architecture.

## 3.2 Secondary Goals

- Make historical content easy to search.
- Make publication history easy to understand.
- Prevent accidental cross-channel publishing.
- Keep the UI extensible for scheduling and analytics.
- Provide reliable media storage.
- Provide clear failure and retry behavior.

---

# 4. Non-Goals for MVP

The following are explicitly outside the first release:

- Automated LinkedIn publishing.
- Automated Instagram publishing.
- Automated WhatsApp publishing.
- Automated YouTube publishing.
- OAuth integrations.
- Social-media analytics.
- Content scheduling.
- AI-generated captions.
- AI-generated images.
- Platform-specific content variants.
- Team collaboration.
- Approval workflows.
- Social inbox management.
- Comment management.
- Browser automation of third-party compose screens.

These may be added later without changing the fundamental domain model.

---

# 5. Target User

The initial target user is a single content creator who operates multiple channels.

Example:

```text
User
 │
 ├── Tech Channel
 │    ├── Technology posts
 │    ├── LinkedIn
 │    ├── Instagram
 │    └── WhatsApp
 │
 └── Gaming Channel
      ├── Gaming posts
      ├── YouTube
      ├── Instagram
      └── WhatsApp
```

The initial product should therefore optimize for a single-user experience while keeping ownership boundaries in the database and backend.

---

# 6. Core Concepts

## 6.1 User

The owner of channels, posts, media, and social accounts.

## 6.2 Channel

A distinct content identity or brand.

Examples:

- Tech
- Gaming
- Personal
- YouTube
- Business

Every post belongs to exactly one channel.

Every social account belongs to exactly one channel.

## 6.3 Post

Reusable content created for a channel.

A post contains:

- Title.
- Caption.
- Optional image/media.
- Status.
- Creation/update timestamps.

## 6.4 Social Account

A social-media destination belonging to a channel.

Examples:

```text
Tech
 ├── LinkedIn - Tech Profile
 ├── Instagram - Tech Instagram
 └── WhatsApp - Tech Channel

Gaming
 ├── YouTube - Gaming Channel
 └── Instagram - Gaming Instagram
```

## 6.5 Post Target

The relationship between a post and a social account.

This represents one publication opportunity.

Example:

```text
Post:
"Understanding Database Sharding"

Targets:
 ├── Tech LinkedIn → Published
 ├── Tech Instagram → Pending
 └── Tech WhatsApp → Published
```

Post targets are the foundation of future API publishing.

---

# 7. Domain Relationship

```text
                         USER
                           │
                           │ 1:N
                           ▼
                       CHANNEL
                      /       \
                     /         \
                  1:N           1:N
                   ▼             ▼
                POSTS      SOCIAL ACCOUNTS
                   │             │
                   │    N:M      │
                   └──────┬──────┘
                          ▼
                    POST TARGETS
```

A post and social account may only be connected if both belong to the same channel.

---

# 8. Functional Requirements

# 8.1 Authentication

The application must provide an authenticated application boundary.

Requirements:

- User must authenticate before accessing private resources.
- Every channel belongs to a user.
- Every post belongs indirectly to a user through its channel.
- Every social account belongs indirectly to a user through its channel.
- API requests must verify ownership.
- No resource should be accessible by guessing UUIDs.

The initial deployment may contain only one user, but the schema and API must still include `user_id`.

---

# 8.2 Channel Management

Users must be able to:

- Create a channel.
- View channels.
- Edit a channel.
- Enable/disable a channel.
- Delete a channel.
- Switch between channels.
- View the number of posts.
- View the number of configured social accounts.

Channel fields:

```text
Name
Description
Slug
Enabled
```

Example:

```text
Tech
Software engineering, system design and programming
```

and:

```text
Gaming
Gaming videos, clips and gaming-related content
```

---

# 8.3 Channel Isolation

A channel is a strict organizational boundary.

For example:

```text
Tech
  Post A
  Post B

Gaming
  Post C
```

Post C must never appear in the Tech post list.

Likewise:

```text
Tech Instagram
Gaming Instagram
```

are two separate social accounts even though they use the same platform.

The backend must prevent:

```text
Tech Post
     +
Gaming Instagram
```

from becoming a valid target.

---

# 8.4 Post Management

Users must be able to:

- Create posts.
- Edit posts.
- Delete posts.
- View posts.
- Search posts.
- Filter posts.
- Upload media.
- Replace media.
- View publication status.
- Select publication targets.

A post must contain:

```text
title
caption
channel
```

Media is optional.

---

# 8.5 Post Status

MVP post statuses:

```text
draft
ready
```

`draft` means the content is still being prepared.

`ready` means the post is available for publishing.

Future statuses may include:

```text
scheduled
archived
```

---

# 8.6 Social Account Management

Users must be able to:

- Add social accounts.
- Edit social accounts.
- Enable/disable accounts.
- Delete accounts.
- View accounts for a channel.

A social account contains:

```text
platform
name
profile URL
posting mode
enabled
```

MVP posting mode:

```text
manual
```

Future posting modes:

```text
api
```

Potential future mode:

```text
api_with_manual_fallback
```

---

# 8.7 Supported Platforms

The initial platform enum should support at least:

```text
linkedin
instagram
whatsapp
youtube
```

Optionally:

```text
x
facebook
threads
```

The application must not treat arbitrary user-entered strings as platforms.

Platform support should be represented by an enum or controlled configuration.

---

# 8.8 Manual Publishing

Manual publishing is the MVP publishing mechanism.

For each target, the UI must provide:

- Caption copy action.
- Media download/access action.
- Destination/open action.
- Mark as Published action.

Example:

```text
Instagram
──────────────
Status: Pending

[ Copy Caption ]
[ Download Image ]
[ Open Instagram ]

[ Mark as Published ]
```

The application must not attempt to automatically manipulate arbitrary third-party websites.

The user performs the actual publication.

After the user publishes externally, they return to PostInTime and click:

```text
Mark as Published
```

The backend records:

```text
status = published
published_at = current timestamp
publishing_mode = manual
```

---

# 8.9 Publication Status

Post targets must support:

```text
pending
publishing
published
failed
skipped
```

For MVP manual publishing, the normal flow is:

```text
pending
   ↓
published
```

Future API publishing may use:

```text
pending
   ↓
publishing
   ↓
published

or

pending
   ↓
publishing
   ↓
failed
```

---

# 8.10 Publication History

Each post should show publication state per social account.

Example:

```text
Understanding Database Sharding

LinkedIn
✓ Published
Aug 16, 2026 11:20 AM

Instagram
○ Pending

WhatsApp
✓ Published
Aug 16, 2026 11:25 AM
```

The post-level summary should show:

```text
2 / 3 published
```

---

# 9. User Experience

# 9.1 Main Navigation

Recommended navigation:

```text
PostInTime

Dashboard

Channels
  Tech
  Gaming

Settings
```

The currently selected channel should be visible at all times.

---

# 9.2 Dashboard

The dashboard should contain:

```text
┌────────────────────────────────────────────────────────┐
│ PostInTime                       Channel: Tech ▼        │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Posts                               [+ New Post]       │
│                                                        │
│ Search posts...                                        │
│                                                        │
│ ┌────────────────────────────────────────────────────┐ │
│ │ Database Sharding                                  │ │
│ │                                                    │ │
│ │ [IMAGE]                                            │ │
│ │                                                    │ │
│ │ LinkedIn ✓   Instagram ○   WhatsApp ✓             │ │
│ │                                                    │ │
│ │ 2 / 3 Published                                    │ │
│ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

---

# 9.3 Channel Switcher

The channel switcher should be available from the main application shell.

Example:

```text
Channel: [ Tech ▼ ]
```

Dropdown:

```text
Tech
Gaming
Personal
──────────────
Manage Channels
```

Switching channels must invalidate/reload channel-specific queries.

---

# 9.4 Channel Overview

A channel dashboard should show:

- Channel name.
- Description.
- Number of posts.
- Number of social accounts.
- Recent posts.
- Publishing summary.

Example:

```text
Tech

24 Posts
3 Social Accounts

Recent Posts
─────────────
Database Sharding
Spring Boot Tips
System Design #12
```

---

# 9.5 Create Post

The create-post page should contain:

```text
Create Post

Title
[________________________________]

Caption
[________________________________]
[________________________________]

Image
[ Drag image here ]
[ Choose File ]

Status
( ) Draft
(•) Ready

[ Save Post ]
```

After save, the user should be able to select publishing targets.

---

# 9.6 Post Details

The post details page should show:

```text
Database Sharding

[IMAGE]

Caption
────────────────
A practical introduction...

Publishing
────────────────

LinkedIn
✓ Published

Instagram
○ Pending
[ Publish ]

WhatsApp
✓ Published
```

---

# 9.7 Social Account Management

Example:

```text
Social Accounts

┌──────────────────────────────────┐
│ LinkedIn                         │
│ Tech LinkedIn                    │
│ linkedin.com/in/example          │
│ Manual                           │
│ Enabled                          │
│                                  │
│ [ Edit ] [ Disable ]             │
└──────────────────────────────────┘
```

Add account:

```text
Platform
[ Instagram ▼ ]

Name
[ Tech Instagram ]

Profile URL
[ https://instagram.com/example ]

Publishing Mode
[ Manual ]

[ Save ]
```

---

# 10. Frontend Technical Requirements

## 10.1 Stack

Required:

- React.
- TypeScript.
- Vite.
- React Router.
- TanStack Query.
- Ant Design.
- React Hook Form.
- Zod.

Optional:

- Axios.
- date-fns.
- Lucide icons.

---

# 10.2 Frontend Architecture

Recommended structure:

```text
frontend/
└── src/
    ├── app/
    │   ├── router/
    │   ├── providers/
    │   └── query-client/
    │
    ├── api/
    │   ├── client.ts
    │   ├── channels.ts
    │   ├── posts.ts
    │   ├── socialAccounts.ts
    │   ├── media.ts
    │   └── publishing.ts
    │
    ├── components/
    │   ├── ChannelSwitcher/
    │   ├── PostCard/
    │   ├── PostList/
    │   ├── PostForm/
    │   ├── MediaUploader/
    │   ├── SocialAccountCard/
    │   ├── PublishTarget/
    │   └── StatusBadge/
    │
    ├── hooks/
    │   ├── useChannels.ts
    │   ├── usePosts.ts
    │   ├── useSocialAccounts.ts
    │   └── usePublishTarget.ts
    │
    ├── pages/
    │   ├── Dashboard/
    │   ├── Channels/
    │   ├── Posts/
    │   ├── SocialAccounts/
    │   └── Settings/
    │
    ├── types/
    └── utils/
```

---

# 10.3 Frontend Routes

```text
/
 /channels
 /channels/:channelId
 /channels/:channelId/posts
 /channels/:channelId/posts/new
 /channels/:channelId/posts/:postId
 /channels/:channelId/social-accounts
 /settings
```

---

# 10.4 Frontend State Management

TanStack Query should be the primary server-state mechanism.

Query keys:

```text
['channels']

['channel', channelId]

['posts', channelId, filters]

['post', channelId, postId]

['social-accounts', channelId]

['targets', channelId, postId]
```

Do not introduce Redux merely for server data.

Use local React state or React Hook Form for UI/form state.

---

# 11. Backend Technical Requirements

# 11.1 Technology Stack

Recommended:

- Java 21.
- Spring Boot 3.x.
- Spring Web.
- Spring Validation.
- Spring Security.
- Spring Data JPA.
- Hibernate.
- PostgreSQL.
- Flyway.
- Spring Boot Actuator.
- Testcontainers.
- Object-storage SDK.

---

# 11.2 Backend Architecture

Use a modular monolith.

Recommended package structure:

```text
backend/
└── src/main/java/com/postintime/
    ├── common/
    │   ├── api/
    │   ├── error/
    │   ├── security/
    │   └── validation/
    │
    ├── auth/
    ├── user/
    ├── channel/
    ├── post/
    ├── media/
    ├── social/
    └── publishing/
        ├── api/
        ├── domain/
        ├── service/
        └── publisher/
```

Use package-by-feature rather than package-by-layer.

---

# 11.3 Backend Responsibilities

## ChannelService

Responsible for:

- Channel creation.
- Channel updates.
- Channel deletion.
- Enable/disable.
- Ownership validation.

## PostService

Responsible for:

- Post creation.
- Post updates.
- Post deletion.
- Post search.
- Post listing.
- Channel validation.

## MediaService

Responsible for:

- Uploads.
- Storage keys.
- Metadata.
- File validation.
- Media deletion.

## SocialAccountService

Responsible for:

- Account creation.
- Account updates.
- Account deletion.
- Enable/disable.
- Platform validation.

## PublishingService

Responsible for:

- Target creation.
- Target validation.
- Publishing orchestration.
- State transitions.
- Publisher selection.

---

# 12. Database Schema

## 12.1 users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(320) NOT NULL UNIQUE,
    display_name VARCHAR(150),
    password_hash TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 12.2 channels

```sql
CREATE TABLE channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    description TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_channel_user_slug
        UNIQUE (user_id, slug)
);
```

## 12.3 media

```sql
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    storage_key VARCHAR(1000) NOT NULL UNIQUE,
    original_filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    width INTEGER,
    height INTEGER,
    checksum VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 12.4 posts

```sql
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    title VARCHAR(300) NOT NULL,
    caption TEXT,
    media_id UUID REFERENCES media(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 12.5 social_accounts

```sql
CREATE TABLE social_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    profile_url TEXT,
    posting_mode VARCHAR(30) NOT NULL DEFAULT 'manual',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    provider_account_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 12.6 post_targets

```sql
CREATE TABLE post_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    social_account_id UUID NOT NULL REFERENCES social_accounts(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    publishing_mode VARCHAR(30) NOT NULL DEFAULT 'manual',
    published_at TIMESTAMPTZ,
    external_post_id VARCHAR(255),
    external_url TEXT,
    error_code VARCHAR(100),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_post_target
        UNIQUE (post_id, social_account_id)
);
```

---

# 13. Database Integrity

The backend must enforce:

1. A post belongs to one channel.
2. A social account belongs to one channel.
3. A target can only connect resources from the same channel.
4. A disabled channel cannot receive new posts.
5. A disabled social account cannot be newly targeted.
6. A post cannot have duplicate targets for the same social account.
7. Deleting a post deletes its targets.
8. Deleting a channel deletes its posts and social accounts after explicit user confirmation.

The cross-channel constraint should be validated by the application service layer and covered by integration tests.

---

# 14. REST API

All APIs use:

```text
/api/v1
```

All timestamps use UTC ISO-8601.

All IDs are UUIDs.

---

# 15. API Error Contract

Standard error:

```json
{
  "timestamp": "2026-08-16T06:00:00Z",
  "status": 400,
  "code": "VALIDATION_ERROR",
  "message": "One or more fields are invalid.",
  "details": [
    {
      "field": "title",
      "code": "REQUIRED",
      "message": "Title is required."
    }
  ],
  "requestId": "01J..."
}
```

---

# 16. Channel API

## List Channels

```http
GET /api/v1/channels
```

Response:

```json
[
  {
    "id": "channel-uuid",
    "name": "Tech",
    "slug": "tech",
    "description": "Software engineering content",
    "enabled": true,
    "postCount": 24,
    "socialAccountCount": 3,
    "createdAt": "2026-08-16T06:00:00Z",
    "updatedAt": "2026-08-16T06:00:00Z"
  }
]
```

## Create Channel

```http
POST /api/v1/channels
Content-Type: application/json
```

```json
{
  "name": "Tech",
  "slug": "tech",
  "description": "Software engineering content"
}
```

## Get Channel

```http
GET /api/v1/channels/{channelId}
```

## Update Channel

```http
PATCH /api/v1/channels/{channelId}
```

```json
{
  "name": "Technology",
  "description": "Software engineering and system design"
}
```

## Delete Channel

```http
DELETE /api/v1/channels/{channelId}
```

Deletion should require explicit UI confirmation.

---

# 17. Post API

## List Posts

```http
GET /api/v1/channels/{channelId}/posts
```

Supported query parameters:

```text
page
size
search
status
targetStatus
sort
```

Example:

```http
GET /api/v1/channels/123/posts?page=0&size=20&search=sharding&sort=updatedAt,desc
```

Response:

```json
{
  "items": [
    {
      "id": "post-uuid",
      "title": "Understanding Database Sharding",
      "caption": "A practical introduction...",
      "media": {
        "id": "media-uuid",
        "url": "https://storage.example/...",
        "contentType": "image/png"
      },
      "status": "ready",
      "publicationSummary": {
        "total": 3,
        "published": 2,
        "pending": 1,
        "failed": 0
      },
      "createdAt": "2026-08-16T06:00:00Z",
      "updatedAt": "2026-08-16T06:00:00Z"
    }
  ],
  "page": 0,
  "size": 20,
  "totalItems": 1,
  "totalPages": 1,
  "hasNext": false,
  "hasPrevious": false
}
```

---

# 18. Create Post

```http
POST /api/v1/channels/{channelId}/posts
Content-Type: application/json
```

```json
{
  "title": "Understanding Database Sharding",
  "caption": "A practical introduction to database sharding.",
  "mediaId": "media-uuid",
  "status": "ready"
}
```

Response:

```http
201 Created
```

```json
{
  "id": "post-uuid",
  "channelId": "channel-uuid",
  "title": "Understanding Database Sharding",
  "caption": "A practical introduction to database sharding.",
  "status": "ready",
  "createdAt": "2026-08-16T06:00:00Z",
  "updatedAt": "2026-08-16T06:00:00Z"
}
```

---

# 19. Update Post

```http
PATCH /api/v1/channels/{channelId}/posts/{postId}
```

```json
{
  "title": "Understanding Database Sharding",
  "caption": "Updated caption..."
}
```

Changing content after publication must not silently reset publication history.

The UI should make it clear that the stored post content changed after previous publication.

---

# 20. Delete Post

```http
DELETE /api/v1/channels/{channelId}/posts/{postId}
```

This deletes associated post targets.

Media should only be physically deleted when no longer referenced or according to a later media lifecycle policy.

---

# 21. Media API

## Upload

```http
POST /api/v1/media
Content-Type: multipart/form-data
```

Form field:

```text
file
```

Response:

```json
{
  "id": "media-uuid",
  "originalFilename": "sharding.png",
  "contentType": "image/png",
  "sizeBytes": 183201,
  "width": 1920,
  "height": 1080,
  "url": "https://storage.example/..."
}
```

## Delete

```http
DELETE /api/v1/media/{mediaId}
```

---

# 22. Social Account API

## List

```http
GET /api/v1/channels/{channelId}/social-accounts
```

## Create

```http
POST /api/v1/channels/{channelId}/social-accounts
```

```json
{
  "platform": "instagram",
  "name": "Tech Instagram",
  "profileUrl": "https://instagram.com/example",
  "postingMode": "manual"
}
```

## Update

```http
PATCH /api/v1/channels/{channelId}/social-accounts/{accountId}
```

## Delete

```http
DELETE /api/v1/channels/{channelId}/social-accounts/{accountId}
```

## Enable

```http
POST /api/v1/channels/{channelId}/social-accounts/{accountId}/enable
```

## Disable

```http
POST /api/v1/channels/{channelId}/social-accounts/{accountId}/disable
```

---

# 23. Post Target API

## List Targets

```http
GET /api/v1/channels/{channelId}/posts/{postId}/targets
```

Response:

```json
[
  {
    "id": "target-uuid",
    "socialAccount": {
      "id": "account-uuid",
      "platform": "linkedin",
      "name": "Tech LinkedIn"
    },
    "status": "published",
    "publishingMode": "manual",
    "publishedAt": "2026-08-16T06:15:00Z",
    "externalPostId": null,
    "externalUrl": null
  }
]
```

---

# 24. Create Targets

```http
POST /api/v1/channels/{channelId}/posts/{postId}/targets
```

Request:

```json
{
  "socialAccountIds": [
    "linkedin-account-uuid",
    "instagram-account-uuid",
    "whatsapp-account-uuid"
  ]
}
```

The backend must:

1. Verify the post belongs to the channel.
2. Verify every account belongs to the same channel.
3. Verify every account is enabled.
4. Create targets.
5. Ignore or reject duplicates according to API contract.
6. Return the resulting target collection.

---

# 25. Manual Publish API

For a manual target:

```http
POST /api/v1/channels/{channelId}/posts/{postId}/targets/{targetId}/publish
```

Response:

```json
{
  "targetId": "target-uuid",
  "status": "pending",
  "publishingMode": "manual",
  "instructions": {
    "copyCaption": true,
    "downloadMedia": true,
    "destinationUrl": "https://instagram.com/example"
  }
}
```

The endpoint does not claim that publication has happened.

The user performs the publication externally.

---

# 26. Mark Published API

```http
POST /api/v1/channels/{channelId}/posts/{postId}/targets/{targetId}/mark-published
```

Request:

```json
{
  "externalUrl": null,
  "notes": "Published manually"
}
```

Response:

```json
{
  "id": "target-uuid",
  "status": "published",
  "publishingMode": "manual",
  "publishedAt": "2026-08-16T06:15:00Z",
  "externalUrl": null
}
```

This operation should be idempotent where practical.

---

# 27. Reset Target

```http
POST /api/v1/channels/{channelId}/posts/{postId}/targets/{targetId}/reset
```

Use cases:

- Retry a failed target.
- Return a mistakenly skipped target to pending.
- Correct a manual workflow.

---

# 28. Publishing Architecture

The publishing system must be abstracted from the beginning.

Recommended interface:

```java
public interface SocialMediaPublisher {

    Platform platform();

    boolean supports(PublishingMode mode);

    PublishResult publish(PublishContext context);
}
```

Initial implementation:

```text
ManualSocialMediaPublisher
```

Future implementations:

```text
LinkedInPublisher
InstagramPublisher
WhatsAppPublisher
YouTubePublisher
XPublisher
```

---

# 29. Publisher Selection

A publisher factory/service should determine the correct implementation.

Conceptually:

```text
PublishingService
       │
       ▼
PublisherFactory
       │
       ├── MANUAL → ManualSocialMediaPublisher
       │
       ├── LinkedIn API → LinkedInPublisher
       │
       ├── Instagram API → InstagramPublisher
       │
       └── YouTube API → YouTubePublisher
```

The frontend should not know which implementation is being used.

---

# 30. Future OAuth Architecture

Future API publishing will require provider connections.

Conceptually:

```text
Social Account
      │
      ▼
Provider Connection
      │
      ├── Provider account ID
      ├── Access token
      ├── Refresh token
      └── Expiration
```

Sensitive credentials must not be returned through ordinary social-account APIs.

Credentials should be encrypted at rest or stored in a dedicated secrets system.

---

# 31. API Publishing Future Flow

```text
User
 ↓
Select Post
 ↓
Select Instagram
 ↓
Publish
 ↓
Post Target
 ↓
PublishingService
 ↓
InstagramPublisher
 ↓
Instagram API
 ↓
External Post ID
 ↓
Post Target = Published
```

The same flow applies to other providers.

---

# 32. Media Architecture

Media must not be stored directly inside PostgreSQL.

Recommended:

```text
React
  │
  ▼
Spring Boot
  │
  ▼
Object Storage
```

Future optimization:

```text
React
  │
  ▼
Presigned Upload URL
  │
  ▼
Object Storage
```

The backend then stores only metadata.

---

# 33. Media Storage Keys

Recommended storage key:

```text
users/{userId}/channels/{channelId}/posts/{postId}/{uuid}.{extension}
```

If media is uploaded before the post exists:

```text
users/{userId}/temporary/{uuid}.{extension}
```

The temporary object can later be associated with a post.

---

# 34. Media Security

Server-side validation must include:

- File size.
- MIME type.
- File signature where practical.
- Supported image formats.
- User ownership.

Never trust:

```text
Content-Type
filename extension
```

alone.

---

# 35. Authentication & Authorization

Every resource must be scoped to the current user.

Authorization chain:

```text
Current User
     ↓
Channel Ownership
     ↓
Post Ownership
     ↓
Target Ownership
```

Example:

```text
GET /channels/A/posts/B
```

must verify:

```text
Post B belongs to Channel A
AND
Channel A belongs to current User
```

Never rely on frontend filtering for authorization.

---

# 36. Security Requirements

The application must:

- Use HTTPS outside local development.
- Protect authentication endpoints.
- Use secure cookies if using session authentication.
- Configure CORS explicitly.
- Configure CSRF appropriately for the chosen auth mechanism.
- Validate uploads server-side.
- Use parameterized database operations.
- Never log secrets.
- Never return provider access tokens.
- Keep secrets outside source control.
- Use secure environment variables or a secrets manager.
- Rate-limit authentication endpoints.
- Return generic authentication failure messages.

---

# 37. Error Handling

Use a centralized Spring `@RestControllerAdvice`.

Recommended error codes:

```text
VALIDATION_ERROR
RESOURCE_NOT_FOUND
ACCESS_DENIED
CHANNEL_DISABLED
ACCOUNT_DISABLED
INVALID_TARGET
CROSS_CHANNEL_TARGET
INVALID_STATE
MEDIA_TOO_LARGE
UNSUPPORTED_MEDIA_TYPE
PUBLISH_FAILED
PROVIDER_ERROR
RATE_LIMITED
AUTH_EXPIRED
```

---

# 38. Logging

Production logs should be structured.

Relevant fields:

```text
requestId
userId
channelId
postId
socialAccountId
targetId
operation
duration
result
```

Never log:

```text
password
accessToken
refreshToken
sessionCookie
authorizationHeader
```

---

# 39. Observability

Spring Boot Actuator should provide:

- Health.
- Readiness.
- Liveness.
- Metrics.

Future metrics:

```text
posts_created_total
media_uploaded_total
publish_attempts_total
publish_success_total
publish_failure_total
api_request_duration
```

---

# 40. Testing Strategy

## Backend

Use:

- JUnit.
- Mockito where appropriate.
- Spring Boot Test.
- MockMvc/WebTestClient.
- Testcontainers PostgreSQL.

Tests should cover:

- Services.
- Controllers.
- Authorization.
- Repository queries.
- State transitions.
- Cross-channel validation.

## Frontend

Use:

- Vitest.
- React Testing Library.
- Playwright for end-to-end tests.

---

# 41. Critical Test Scenarios

1. Create Tech channel.
2. Create Gaming channel.
3. Create Tech post.
4. Verify Gaming does not contain Tech post.
5. Add Tech Instagram.
6. Add Gaming Instagram.
7. Attempt to attach Gaming Instagram to Tech post.
8. Verify request is rejected.
9. Add three targets to a Tech post.
10. Mark one published.
11. Refresh page.
12. Verify one target remains published.
13. Disable Instagram.
14. Verify new targets cannot use it.
15. Upload invalid media.
16. Verify server rejection.
17. Attempt to access another user's channel.
18. Verify authorization failure.
19. Delete a post.
20. Verify targets disappear.

---

# 42. Recommended Indexes

```sql
CREATE INDEX idx_channels_user_id
    ON channels(user_id);

CREATE INDEX idx_posts_channel_updated
    ON posts(channel_id, updated_at DESC);

CREATE INDEX idx_social_accounts_channel
    ON social_accounts(channel_id);

CREATE INDEX idx_post_targets_post
    ON post_targets(post_id);

CREATE INDEX idx_post_targets_status
    ON post_targets(status);

CREATE INDEX idx_post_targets_social_account
    ON post_targets(social_account_id);
```

---

# 43. Pagination

All potentially large lists should be paginated.

Response:

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalItems": 125,
  "totalPages": 7,
  "hasNext": true,
  "hasPrevious": false
}
```

The frontend should never request an unbounded historical post list.

---

# 44. Search

MVP search should support:

```text
title
caption
```

Example:

```http
GET /api/v1/channels/{channelId}/posts?search=database
```

Later, PostgreSQL full-text search can be introduced if required.

---

# 45. Post Target Selection UX

When creating a post:

```text
Publish To

☑ LinkedIn
☑ Instagram
☐ WhatsApp

[ Create Post ]
```

Alternatively, allow target selection after creation.

MVP recommendation:

**Create the post first, then choose targets on the post details page.**

This keeps the creation form simple.

---

# 46. Manual Publishing UX Details

When clicking Publish:

```text
Publish to Instagram

Caption
────────────────────────────
A practical introduction...

[ Copy Caption ]

Media
────────────────────────────
[ image preview ]

[ Download Image ]

Destination
────────────────────────────
https://instagram.com/example

[ Open Instagram ]

After you publish:
[ Mark as Published ]
```

The UI should prevent accidental publication marking by making the action explicit.

---

# 47. Editing Published Content

If a post has already been published and its caption changes:

```text
Stored Post
    ↓
Changed
    ↓
Existing targets remain published
```

Do not automatically mark them pending.

Instead, future UI may show:

```text
LinkedIn
Published
Content changed since publication
[Republish]
```

This avoids destructive implicit behavior.

---

# 48. Future Scheduling

Scheduling should eventually operate at the **post-target** level.

Example:

```text
Post
 ├── LinkedIn → Aug 20, 09:00
 ├── Instagram → Aug 20, 18:00
 └── WhatsApp → Aug 21, 10:00
```

Future fields:

```text
scheduled_at
retry_count
next_retry_at
```

This is another reason not to put scheduling directly on `posts`.

---

# 49. Future Platform-Specific Content

A base post may eventually have platform-specific variants.

Example:

```text
Base Post
 ├── Title
 ├── Caption
 └── Image

Instagram Variant
 ├── Caption override
 └── Image override

LinkedIn Variant
 └── Caption override
```

Potential future entity:

```text
post_variants
```

This should not be implemented in MVP.

---

# 50. Future Analytics

The `post_targets` model already provides the correct place for external publication identifiers:

```text
external_post_id
external_url
```

Future analytics can reference the target.

Possible metrics:

```text
impressions
reach
likes
comments
shares
saves
clicks
```

Analytics should be modeled separately rather than adding dozens of nullable columns to `post_targets`.

---

# 51. Deployment Architecture

Recommended:

```text
                 Internet
                    │
                    ▼
              HTTPS / Proxy
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
    React Static          Spring Boot
       Assets                  API
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
                PostgreSQL          Object Storage
```

Frontend can be hosted on a static/CDN platform.

Backend can run as a Docker container.

PostgreSQL should use persistent or managed storage.

Object storage should remain outside the application container.

---

# 52. Local Development

Recommended repository:

```text
postintime/
├── frontend/
├── backend/
├── infra/
├── docs/
├── docker-compose.yml
├── .env.example
└── README.md
```

Local services:

```text
PostgreSQL
Object Storage / local storage
Spring Boot
Vite
```

---

# 53. Docker Compose

Initial infrastructure can be:

```yaml
services:

  postgres:
    image: postgres:latest
    environment:
      POSTGRES_DB: postintime
      POSTGRES_USER: app
      POSTGRES_PASSWORD: change-me
    ports:
      - "5432:5432"
```

Object storage can initially be Supabase Storage, S3-compatible storage, or MinIO for local development.

---

# 54. Environment Configuration

Example:

```text
SPRING_PROFILES_ACTIVE=local

DATABASE_URL=jdbc:postgresql://localhost:5432/postintime
DATABASE_USERNAME=app
DATABASE_PASSWORD=change-me

STORAGE_ENDPOINT=...
STORAGE_BUCKET=postintime

APP_BASE_URL=http://localhost:8080
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

Secrets must never be committed.

---

# 55. Flyway

Migration structure:

```text
V1__create_users.sql
V2__create_channels.sql
V3__create_media.sql
V4__create_posts.sql
V5__create_social_accounts.sql
V6__create_post_targets.sql
V7__add_indexes.sql
```

Never modify an already-applied migration in a shared environment.

---

# 56. Recommended Development Phases

## Phase 0 — Foundation

Build:

- Repository.
- Docker Compose.
- PostgreSQL.
- Spring Boot.
- React/Vite.
- Flyway.
- Base authentication boundary.
- CI.

Outcome:

```text
Application boots successfully.
```

## Phase 1 — Channels

Build:

- Channel schema.
- Channel APIs.
- Channel UI.
- Channel switcher.

Outcome:

```text
Tech
Gaming
```

can be managed independently.

## Phase 2 — Posts

Build:

- Post schema.
- CRUD APIs.
- Post list.
- Post detail.
- Post form.
- Search/filter.

Outcome:

```text
Tech
 ├── Post A
 ├── Post B
 └── Post C
```

## Phase 3 — Media

Build:

- Upload.
- Object storage.
- Image preview.
- Download.
- Media metadata.

## Phase 4 — Social Accounts

Build:

- Social account schema.
- CRUD APIs.
- Account UI.
- Platform selection.
- Enable/disable.

## Phase 5 — Publishing

Build:

- Post targets.
- Target selection.
- Manual publishing.
- Mark published.
- Publication status.

This is the **MVP completion point**.

## Phase 6 — Production Hardening

Build:

- Full test suite.
- Security review.
- Error handling.
- Observability.
- Backup strategy.
- Deployment pipeline.

## Phase 7 — API Publishing Foundation

Build:

- Provider abstraction.
- OAuth connection model.
- Secure token storage.
- Publisher factory.

## Phase 8 — First API Integration

Choose one platform and implement:

```text
OAuth
 ↓
Account Connection
 ↓
Publish
 ↓
External Post ID
 ↓
Publication URL
```

## Phase 9 — Scheduling

Add:

```text
scheduled_at
retry_count
next_retry_at
```

and background workers.

## Phase 10 — Analytics

Add platform-specific metrics.

---

# 57. Definition of Done — MVP

The MVP is complete when:

- User can authenticate.
- User can create multiple channels.
- Channels are isolated.
- User can create posts.
- Posts support title and caption.
- Posts support image upload.
- User can view historical posts.
- User can search posts.
- User can configure multiple social accounts per channel.
- Same platform can exist under multiple channels.
- User can select social accounts as post targets.
- Each target has independent publication state.
- Manual publishing workflow works.
- User can mark a target as published.
- Publication state persists.
- Cross-channel targeting is impossible.
- Unauthorized resource access is blocked.
- Database schema is managed with Flyway.
- Backend has integration tests.
- Frontend has core component/e2e coverage.
- Application runs through documented local-development steps.

---

# 58. Future Product Roadmap

```text
                    PostInTime
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
       Content       Publishing     Analytics
          │             │             │
          │             ├── Manual    ├── Reach
          │             ├── API       ├── Impressions
          │             └── Scheduled ├── Engagement
          │                           └── Growth
          │
          ├── Channels
          ├── Posts
          ├── Media
          └── Variants
```

Potential future capabilities:

- Scheduled publishing.
- Automatic publishing.
- Platform-specific captions.
- Platform-specific media.
- AI caption assistance.
- Content calendar.
- Analytics dashboard.
- Best-time-to-post recommendations.
- Post templates.
- Recurring content.
- Draft workflows.
- Collaboration.
- Multiple users.
- Team permissions.
- Approval workflows.

---

# 59. Architectural Principles

The following principles should be treated as non-negotiable:

## Principle 1 — Channel is the organizational boundary

Posts and social accounts belong to channels.

## Principle 2 — Posts are content, not publications

A post is reusable content.

Publishing happens through post targets.

## Principle 3 — Publishing is an abstraction

Manual publishing is only the first implementation.

## Principle 4 — Never mix channel identities

A Tech post must never accidentally publish through Gaming social accounts.

## Principle 5 — Keep provider logic isolated

LinkedIn/Instagram/WhatsApp-specific code must not leak into core post management.

## Principle 6 — Store external identifiers early

`external_post_id` and `external_url` should exist before API publishing.

## Principle 7 — Backend owns authorization

The frontend is not a security boundary.

## Principle 8 — Keep the MVP simple

Do not implement scheduling, OAuth, analytics, variants, or microservices until there is a concrete need.

---

# 60. Final Architecture

```text
┌───────────────────────────────────────────────────────┐
│                       PostInTime                      │
├───────────────────────────────────────────────────────┤
│                                                       │
│  React + TypeScript + Vite                            │
│  ├── Channel Dashboard                                │
│  ├── Post Management                                  │
│  ├── Media Upload                                     │
│  ├── Social Accounts                                  │
│  └── Publishing UI                                    │
│                                                       │
├───────────────────────────┬───────────────────────────┤
│                           │                           │
│        Spring Boot        │        PostgreSQL         │
│                           │                           │
│  ├── Auth                 │  ├── Users               │
│  ├── Channels             │  ├── Channels            │
│  ├── Posts                │  ├── Posts               │
│  ├── Media                │  ├── Media               │
│  ├── Social Accounts      │  ├── Social Accounts     │
│  └── Publishing           │  └── Post Targets        │
│                           │                           │
├───────────────────────────┴───────────────────────────┤
│                                                       │
│                    Object Storage                     │
│                                                       │
├───────────────────────────────────────────────────────┤
│                                                       │
│ Future Publishing Providers                           │
│                                                       │
│  LinkedIn │ Instagram │ WhatsApp │ YouTube │ X       │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

# 61. Product North Star

**PostInTime should make managing multiple content channels feel like managing one organized workspace.**

The user should think:

```text
What do I want to post?
        ↓
Which channel is it for?
        ↓
Where do I want it published?
        ↓
Publish it.
```

PostInTime handles the organization, storage, targeting, and publication tracking.

The first version is deliberately manual.

The architecture is deliberately ready for automation.

That balance is the core design decision behind the product.
