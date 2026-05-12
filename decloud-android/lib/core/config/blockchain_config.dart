// Switch network at build time:
//   flutter run  --dart-define=NETWORK=local
//   flutter run  (defaults to sepolia)
const String _network = String.fromEnvironment('NETWORK', defaultValue: 'sepolia');

// ── Sepolia ──────────────────────────────────────────────────────────────────
const String _sepoliaRpc         = "https://sepolia.infura.io/v3/eaea60d233f64893b5926f90422b7b78";
const String _sepoliaFallbackRpc = "https://sepolia.drpc.org";
const String _sepoliaDcld        = "0xB157028062Dc78D8e0Ec1A14F7a5a09D6c75249F";
const String _sepoliaEscrow      = "0xBd1550ccb0388F88Ef943c0196F439e0586194b3";

// ── Hardhat local ────────────────────────────────────────────────────────────
// On Android emulator 10.0.2.2 reaches the host machine's localhost.
// On a physical device set LOCAL_RPC to your machine's LAN IP, e.g. 192.168.x.x:8545.
const String _localRpc    = String.fromEnvironment('LOCAL_RPC',    defaultValue: 'http://10.0.2.2:8545');
const String _localDcld   = String.fromEnvironment('LOCAL_DCLD',   defaultValue: '0x5FbDB2315678afecb367f032d93F642f64180aa3');
const String _localEscrow = String.fromEnvironment('LOCAL_ESCROW', defaultValue: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512');

// ── Active config (selected by NETWORK) ─────────────────────────────────────
final bool _isLocal = _network == 'local';

final String rpcUrl              = _isLocal ? _localRpc    : _sepoliaRpc;
final String fallbackRpcUrl      = _isLocal ? _localRpc    : _sepoliaFallbackRpc;
final String dcldTokenAddress    = _isLocal ? _localDcld   : _sepoliaDcld;
final String escrowContractAddress = _isLocal ? _localEscrow : _sepoliaEscrow;

final int chainId = _isLocal ? 31337 : 11155111;

// Legacy const aliases kept for backward compatibility
const String sepoliaRpcUrl         = _sepoliaRpc;
const String sepoliaFallbackRpcUrl = _sepoliaFallbackRpc;
