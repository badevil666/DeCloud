# Decloud Android Wallet

A **non-custodial Android wallet** built with **Flutter** for the **Decloud** project.  
This wallet securely manages user keys, connects to the **Ethereum Sepolia testnet**, and displays balances of the **DCLD ERC-20 token**.

The wallet is designed as part of a decentralized storage ecosystem where users earn and spend tokens for storage services.

---

## 🚀 Features

- 🔐 **Non-custodial wallet**
  - BIP-39 mnemonic generation
  - BIP-44 Ethereum key derivation
  - Private keys never leave the device

- 🛡 **Secure local storage**
  - Encrypted storage using platform keystore
  - No backend custody

- 🌐 **Ethereum integration**
  - Sepolia testnet support
  - ERC-20 token interaction (DCLD)
  - Real on-chain balance fetching

- 💰 **Wallet UI**
  - Animated wallet balance card
  - Wallet address display
  - Clean, modern Flutter UI

- 🔄 **Wallet management**
  - Create new wallet
  - Import wallet using recovery phrase
  - Disconnect / reset wallet (development-ready)

---

## 🧱 Tech Stack

- Flutter (Dart)
- web3dart
- Ethereum (Sepolia Testnet)
- ERC-20 Smart Contracts
- Flutter Secure Storage

---

## 📁 Project Structure

```text
lib/
├── core
│   ├── config
│   │   └── blockchain_config.dart
│   ├── constants.dart
│   ├── crypto
│   │   ├── erc20_abi.dart
│   │   ├── eth_service.dart
│   │   ├── keystore_service.dart
│   │   ├── mnemonic_service.dart
│   │   └── wallet_service.dart
│   └── storage
│       └── secure_storage.dart
├── main.dart
├── screens
│   ├── files
│   │   └── filesScreen.dart
│   ├── home
│   │   └── homeScreen.dart
│   ├── mainNavigation.dart
│   ├── settings
│   ├── upload
│   │   └── uploadScreen.dart
│   └── wallet
│       ├── create_wallet_screen.dart
│       ├── import_wallet_screen.dart
│       ├── wallet_gate_screen.dart
│       ├── wallet_home_screen.dart
│       └── wallet_setup_screen.dart
└── widgets
    ├── AnimateCloud.dart
    ├── animatedCloudLottie.dart
    ├── animated_bottom_bar.dart
    ├── animated_stat_card.dart
    ├── drifting_asteroids.dart
    ├── mnemonic_backup_widget.dart
    ├── night_sky_background.dart
    ├── twinkling_stars_painter.dart
    └── uploadButton.dart