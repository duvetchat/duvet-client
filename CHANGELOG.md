## 1.0.0 – 2026-10-22

The REST client now follows the API as the desktop app
(`desktop-electrobun/src/mainview/src/lib/api/`) uses it, and its models
follow what the server really sends. **This release breaks the 0.x API**: see
"Breaking changes".

### Breaking changes

- **Default instance:** `ApiRouter` defaults to `api.duvet.chat` (REST),
  `ws.duvet.chat` (gateway) and `duvet.chat`. The `andremor.eu.org` hosts are
  no longer Duvet instances.
- **Argument order — still compiles, so check your calls:**
  `assignRoleToMember` and `removeRoleFromMember` now take
  `(spaceId, roleId, memberId)` (was `(spaceId, memberId, roleId)`).
  `updateMessage` and `deleteMessage` take `(messageId, …, roomId)`, as the
  desktop app does.
- **Renamed methods** (the desktop app's names):

  | 0.x | 1.0.0 |
  |---|---|
  | `sendMessageWithFiles(roomId, files, content:)` | `sendMessage(roomId, content, files:)` |
  | `editMessage` | `updateMessage` |
  | `getMessagesThread` | `getMessageThread` |
  | `sendRoomTypingIndicator` | `sendTypingIndicator` |
  | `getUnreadCount` | `getMentionCounts` |
  | `removeReaction` | `removeRoomReaction` |
  | `updateRoomOverwrite` | `upsertRoomOverwrite` |
  | `unassignRoleFromMember` | `removeRoleFromMember` |
  | `getPendingFriendRequests` | `getPendingRequests` |
  | `updateMe` | `updateUser` |
  | `signUp` | `signIn` (registers an account, as the API's `/auth/signin`) |

- **Changed signatures:** `createRoom(spaceId, name, type, {parentId})`;
  `createRole(spaceId, name, {…})`; `createEmoji`/`createSticker(spaceId,
  name, file)`; `createRoomInvite(spaceId, roomId, maxAge)`; `getMessages`
  answers `List<GatewayMessage>` (was `List<Message>`); `createSpace` answers
  nothing.
- **Removed** `getSpace`, `deleteSpace`, `getRoom` and `getRooms`: the API has
  no such routes.
- **`RestClient`:** `sessionCookie` is gone. The session token comes from the
  login response's `session_token` (`sessionToken`), and `authHeaders` no
  longer includes `Content-Type`.
- **Models now match the server's JSON:**
  - `UserMeResult` has no `email` or `password` (the API sends neither).
    `birthdate` is a `DateTime?`. Added `flags`, `badges` and `isBot`.
  - `ReferencedMessage` has no `id`.
  - `GatewayMessage.authorId` is nullable: webhook messages have none.
  - `GatewayRoom.spaceId` and `Attachment.messageId` are nullable.
  - `Conversation` has `type`, `ownerId`, `deletedAt` and `members`
    (`ConversationMember`) in place of `memberIds`. `DirectMessage.user` is a
    `ConversationUser`, and its `conversationId` is nullable.
  - `FriendRequest` has `recipientId` (was `receiverId`), plus `updatedAt` and
    the other user's details. `Friend` has `requestId`, `senderId`,
    `recipientId` and the user's details.
  - The gateway's FRIEND_REQUEST_CREATE and FRIEND_REQUEST_ACCEPT carry
    `FriendRequestCreateEvent` and `FriendRequestAcceptEvent`.
  - READY's `activeCalls` hold `CallVoiceState`s: a call's voice states have
    no room.
  - `VoiceJoinedEvent` has `roomId` and `answer` (a `SessionDescription`),
    not `userId` and `sdp`.
  - `FriendRequestRejectEvent.id` (was `requestId`; the gateway sends `id`).
  - `MemberRoleEvent.spaceId` is nullable: MEMBER_ROLE_REMOVE doesn't carry
    it.
  - `CallIncomingEvent` has no `memberIds` (the gateway sends none).

### Fixed

- Paths: accepting and rejecting friend requests, and mention counts
  (`/users/@me/…`).
- Multipart requests (files) were sent with a JSON `Content-Type`, so every
  upload failed. File parts now declare their media type, which the API keeps.
- Emojis and stickers send their file as `file` (was `files`). Messages with
  files send their reply as `message_reference` (was `reference`).
- Emoji names in reaction URLs were encoded twice.
- Updating a room, role or the user sent `null` for every field not given,
  which could clear them. Now only the fields given are sent; `clear…` flags
  send an explicit `null`.
- Responses the models couldn't parse:
  - `/users/@me`: the models required `email` and `password`.
  - Referenced messages: required an `id`.
  - Webhook messages: no `author_id`.
  - A member added to a conversation: may come without `user`.
  - Gateway: READY (while in a call), VOICE_JOINED, MEMBER_ROLE_REMOVE,
    FRIEND_REQUEST_REJECT and CALL_INCOMING all failed to parse, so the
    client dropped them.
- `Embed` can now be sent (it had no `toJson`).
- API errors no longer include the auth headers.

### Added

- Conversations and DMs: messages, pins, search, voice notes, typing and
  recording indicators, reactions.
- Room messages: pins, search, `getMessagesAfter`, voice notes, recording
  indicator.
- Read acks (`ackRoom`, `ackConversation`), sent at most once per room or
  conversation every 3 s with the newest message, as the desktop app does.
- Invites, webhooks, interactions, and space commands (cached for 5 minutes).
- Space members (paged), space updates (with icon and banner), attachments,
  storage and buckets.
- The user's storage, attachments and buckets. Profile images with a crop.
- Teams, team invites, applications and bots.
- The email/password endpoints (verify, reset, change email) and `logout`.
- `RestClient(client, token:, sessionToken:)` resumes a saved session.
  `refreshSession()` renews it, waiting out a 429. A request that gets a 401
  renews the session once and is sent again; concurrent requests share one
  refresh. A rejected refresh forgets the tokens.
- `RestMethods.request(…)` for routes the client doesn't wrap.
- Models: `SpaceMemberWithUser`, `MessageSearch`, `MessageSearchResponse`,
  `StorageStatus`, `StorageBucket`, `BucketPayload`, `Team`, `TeamMember`,
  `TeamInvite`, `Application`, `BotUser`, `InviteInfo`, `InviteLink`,
  `Webhook`, `SpaceCommands`, `ApplicationCommand`, `CommandOption`,
  `ComponentUse`, `CommandUse`, `InteractionMetadata`, `MessageFlag`,
  `EmbedType`, `MessageType.pinNotice`.
- `GatewayMessage`: `webhookId`, `pinnedAt`, `flags`, `components`,
  `interactionMetadata`. `GatewayUser`: `flags`, `badges`, `isBot`.
  `GatewaySpace.icon`. `Attachment`: `url`, `deletedAt`. `Embed.provider`.
- Dependencies: `http_parser`. Dev dependencies: `test`.

### Tests

- `test/requests_test.dart`: what each method sends (method, path, query,
  body, form fields), and the session renewal, against a mock server.
- `test/models_test.dart`: every model parses the server's JSON, and every
  gateway event the client handles parses through `GatewayEnvelope` (a test
  fails when an event has no fixture). CONVERSATION_DELETE,
  GUILD_MEMBER_ADD and GUILD_MEMBER_REMOVE are still handled, but neither the
  API nor the gateway sends them.
- `test/fixtures/` holds the server's own response and event types (the Go
  structs that the handlers pass to `c.JSON` and that the API and the gateway
  publish), marshalled with `encoding/json` in three variants:
  - **full:** every field set;
  - **nulls:** every nullable field null and every list empty;
  - **partial:** nested objects present but their nullable fields null.

  `tool/fixtures/generate.sh` makes them again from the `api` and `gateway`
  checkouts.
- `test/live_test.dart`: read-only checks against the live instance.
  - Run `DUVET_LIVE=1 dart test -t live`.
  - With `DUVET_EMAIL` and `DUVET_PASSWORD` set, it also parses the account's
    data, READY and the SPACE_CREATE events.
  - It prints which responses it parsed.
- The command-line example moved from `test/` to `example/`.

## 0.1.1
- Fix: issue with authentication
- Tidy up the code
- Add a more reliable test module
- Tested on my own instance

## 0.1.0

- **Migrate to null safety** (requires Dart SDK >=3.0.0).
- Complete rewrite of the client API:
  - Gateway client with WebRTC support (`lib/gateway/`).
  - HTTP methods and REST helpers (`lib/http/`).
  - Data models for gateway envelopes and types (`lib/models/`).
  - Robust error handling (`lib/errors.dart`)
- Update dependencies:
  - `http: ^1.2.0`
  - `web_socket_client: ^0.1.0`
- Add development dependency on `lints: ^3.0.0`.
- Improve error handling with dedicated error classes.
- Add utility extensions and helper functions.

## 0.0.2 – unpublished (pre‑null safety)

- Initial proof‑of‑concept version.
- Not null‑safe; requires Dart SDK <3.0.0.
