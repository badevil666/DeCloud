# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device or emulator
flutter run

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze for lint issues
flutter analyze

# Fetch dependencies
flutter pub get
```

## Architecture

**Decloud** is a Flutter non-custodial Ethereum wallet app targeting Android, with a decentralized storage UI. It connects to the **Ethereum Sepolia testnet** and manages a custom **DCLD ERC-20 token**.

### State management
The app uses a simple singleton `ChangeNotifier` pattern — no Provider/Riverpod/Bloc. `AuthNotifier` (`lib/core/auth_notifier.dart`) is the single global state object. It is initialized at startup in `main.dart` and listened to directly by widgets via `addListener`.

### Navigation
`MainNavigation` uses an `IndexedStack` to keep all 5 tabs alive (Files, Upload, Home, Wallet, Profile). The wallet tab renders `WalletGateScreen`, which checks `AuthNotifier.walletAddress` and shows either `WalletHomeScreen` or `WalletSetupScreen`.

### Core layers (`lib/core/`)
| Path | Purpose |
|------|---------|
| `config/blockchain_config.dart` | Hardcoded Sepolia RPC URL and DCLD contract address |
| `config/api_config.dart` | Default backend base URL (`https://api.decloud.io`) |
| `config/api_config_service.dart` | User-overridable backend URL; persisted in `SecureStorage` under `api_base_url` |
| `constants.dart` | Global design tokens (colors, gradients) |
| `crypto/mnemonic_service.dart` | BIP-39 mnemonic generation + BIP-44 key derivation (`m/44'/60'/0'/0/0`) |
| `crypto/wallet_service.dart` | Creates/imports wallet, persists private key and address via `SecureStorage` |
| `crypto/eth_service.dart` | Fetches DCLD token balance from the chain via `web3dart` |
| `crypto/erc20_abi.dart` | Minimal ERC-20 ABI JSON string |
| `crypto/keystore_service.dart` | AES-GCM-256 encryption helper (used for file key wrapping) |
| `auth/auth_service.dart` | Sign-in-with-Ethereum (SIWE/EIP-191): fetches nonce → signs → POSTs → stores JWT |
| `api/auth_api.dart` | Raw HTTP calls for `/client/login` and `/client/register` |
| `upload/upload_service.dart` | Processes file in an `Isolate` then POSTs manifest to `/client/upload` |
| `upload/file_processor.dart` | File chunking / manifest building (runs off UI thread) |
| `upload/upload_models.dart` | Upload manifest data models |
| `files/files_service.dart` | GET `/client/files` — returns `List<FileRecord>` |
| `files/file_record.dart` | Model for a stored file entry |
| `storage/secure_storage.dart` | Thin wrapper around `FlutterSecureStorage` (Android: `encryptedSharedPreferences`) |
| `auth_notifier.dart` | Singleton `ChangeNotifier`; reads `is_logged_in` and `wallet_address` from secure storage |

### Secure storage keys
| Key | Value |
|-----|-------|
| `wallet_private_key` | Hex-encoded 32-byte private key (no 0x prefix) |
| `wallet_address` | Checksummed Ethereum address |
| `is_logged_in` | String `"true"` when wallet is active |
| `auth_token` | JWT returned by the backend after SIWE authentication |
| `api_base_url` | User-configured backend URL (optional; falls back to `apiBaseUrl` in `api_config.dart`) |

### Backend authentication (SIWE)
`AuthService` implements EIP-191 `personal_sign` against the Decloud backend:
1. `GET /client/register` or `/client/login` with `{ wallet_address }` → returns `nonce`
2. Sign `"\x19Ethereum Signed Message:\n" + len(nonce) + nonce` with the wallet private key
3. `POST /client/register` or `/client/login` with `{ wallet_address, nonce, signature }` → returns JWT
4. JWT stored under `auth_token` in `SecureStorage`; retrieved by `AuthService.getToken()`

### Wallet flow
1. No wallet → `WalletSetupScreen` (create or import)
2. **Create**: `WalletService.createWallet()` → BIP-39 mnemonic → BIP-44 key → store in `SecureStorage` → show mnemonic backup → `AuthNotifier.login()`
3. **Import**: user pastes mnemonic → `WalletService.importWallet()` → same storage flow
4. Wallet present → `WalletHomeScreen` shows balance (via `EthService.getTokenBalance`) and transactions

### UI conventions
- Dark theme: near-black background `0xFF0F1115`, card `0xFF181A20` (defined in `lib/core/constants.dart`)
- Primary gradient: cyan → purple → red (horizontal) — `kPrimaryGradient`
- Reusable widgets live in `lib/widgets/`; screen-specific sub-widgets live under their screen folder (e.g., `lib/screens/wallet/sections/`)
