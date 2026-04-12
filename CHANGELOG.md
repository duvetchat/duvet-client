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
