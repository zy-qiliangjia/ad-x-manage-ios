## MODIFIED Requirements

### Requirement: Platform tokens are stored as plaintext
The `platform_tokens` table SHALL store `access_token` and `refresh_token` as plaintext strings. The columns SHALL be named `access_token` and `refresh_token` (previously `access_token_enc` and `refresh_token_enc`). No encryption or decryption SHALL be applied when reading or writing tokens. The `encrypt` package SHALL NOT be imported by any service.

#### Scenario: OAuth callback saves plaintext access token
- **WHEN** a user completes OAuth for TikTok and `Callback` is invoked
- **THEN** the raw `access_token` string is written directly to `platform_tokens.access_token` without AES encryption

#### Scenario: Service reads plaintext token
- **WHEN** `sync/service.go` or any other service retrieves an access token for a platform API call
- **THEN** it reads `token.AccessToken` directly without calling `encrypt.Decrypt`

#### Scenario: Token refresh stores plaintext
- **WHEN** the token refresh flow runs and receives a new access_token from the platform
- **THEN** the new value is written to `platform_tokens.access_token` as plaintext

## REMOVED Requirements

### Requirement: encryptKey parameter in service constructors
**Reason**: Token encryption has been removed; no service needs the key.
**Migration**: Remove `encryptKey string` from the `New(...)` function signature of `oauth`, `sync`, `advertiser`, `campaign`, `adgroup`, and `stats` services. Remove the `AppEncryptKey` field from `config.Config` and the `APP_ENCRYPT_KEY` environment variable.
