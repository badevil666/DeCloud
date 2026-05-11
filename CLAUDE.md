# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

DeCloud is a decentralized cloud storage platform with four components:

| Component | Stack | Purpose |
|-----------|-------|---------|
| `DecloudBackend/` | Node.js/Express + PostgreSQL | Central API (auth, file metadata, deal management) |
| `DecloudRelay/` | Node.js/WebSocket | Data relay tunneling file chunks between clients and peers |
| `desktop/` | Electron + TypeScript | Storage node desktop app (stores encrypted chunks, earns tokens) |
| `decloud-android/` | Flutter/Dart | Non-custodial mobile wallet + storage client |

Each component has its own `CLAUDE.md` with detailed guidance; this file covers cross-cutting concerns and the system-level architecture.

## Commands

### Backend (`DecloudBackend/`)
```bash
npm run dev      # Development server (nodemon auto-reload)
npm start        # Production server
npm run local    # HOST=0.0.0.0 development server
```
No test framework configured — `npm test` exits with an error.

### Relay (`DecloudRelay/`)
```bash
npm run dev      # Development server (nodemon auto-reload)
npm start        # Production server
npm run local    # HOST=0.0.0.0 development server
```

### Desktop (`desktop/`)
```bash
npm run build    # tsc — compile TypeScript
npm start        # tsc && electron .
```

### Mobile (`decloud-android/`)
```bash
flutter pub get                     # Fetch dependencies
flutter run                         # Run on device/emulator
flutter build apk --release         # Build release APK
flutter test                        # Run all tests
flutter test test/widget_test.dart  # Run single test file
flutter analyze                     # Lint
```

## System Architecture

### Authentication Flow (SIWE / EIP-191)
All components (backend, desktop, mobile) use wallet-based Sign-In with Ethereum:
1. `GET /client/login?address=<eth_addr>` or `/client/register` → backend returns nonce
2. Client signs nonce with wallet private key (EIP-191 `personal_sign`)
3. `POST /client/login` or `/client/register` with `{ wallet_address, nonce, signature }` → JWT
4. JWT used as Bearer token for all subsequent requests

The backend verifies signatures via `ethers.js` `verifyMessage`. Nonces expire in 10 minutes and are stored in the `auth_nonces` DB table.

### File Upload Flow
1. Mobile/client builds a file manifest: chunks file, computes SHA-256 commitments, builds Merkle root
2. `POST /client/upload` — backend validates manifest cryptographically (7-stage pipeline in `uploadController.js`)
3. `POST /client/upload/confirm` — backend allocates storage peers, issues relay tokens
4. Client connects to `DecloudRelay` WebSocket and streams chunks; relay pairs client ↔ peer connections
5. Desktop peer stores encrypted chunk, sends signed storage deal back to backend

### File Download Flow
1. `POST /client/files/:fileId/download` — backend selects best peer replica per chunk, issues relay tokens
2. Client connects to relay with token; relay pairs client ↔ peer
3. Chunks stream through relay to client

### Relay Protocol
- **Upload:** JSON handshake `{token, role}` (role = `"client"` or `"peer"`), then binary data relay
- **Download:** Query params `?token=<t>&chunkIndex=<i>&role=<r>`, direct binary relay
- Tokens are 64-char lowercase hex strings validated by the relay

### Desktop Node Lifecycle
1. Electron app loads/creates BIP-39 wallet via `walletService.ts`
2. Auto-authenticates with backend (SIWE) via `authService.ts`
3. Registers on-chain with `NodeRegistry` smart contract (Sepolia: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`)
4. Maintains WebSocket connection to backend for chunk assignment events

### Blockchain
- **Network:** Ethereum Sepolia testnet
- **Token:** DCLD (custom ERC-20)
- **Smart contract interactions:** `ethers.js` in backend/desktop; `web3dart` in mobile
- **Deal signing:** EIP-712 typed data (`signDeal.js` in backend, signed by storage peers)

## Environment Variables

**DecloudBackend/.env:**
```
DATABASE_URL=       # Neon PostgreSQL connection string
JWT_SECRET=         # JWT signing secret
JWT_EXPIRES_IN=7d
PORT=3000
NODE_ENV=development
```

**DecloudRelay/.env:**
```
PORT=4000
HANDSHAKE_TIMEOUT_MS=10000
```
