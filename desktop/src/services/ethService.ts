import { ethers } from 'ethers';

const NETWORK = (process.env.NETWORK || 'sepolia').toLowerCase();

const networkConfig = {
    sepolia: {
        rpcUrl:       'https://sepolia.infura.io/v3/eaea60d233f64893b5926f90422b7b78',
        chainId:      BigInt(11155111),
        dcldToken:    process.env.DCLD_TOKEN_ADDRESS          || '0xB157028062Dc78D8e0Ec1A14F7a5a09D6c75249F',
        escrowAddr:   process.env.ESCROW_CONTRACT_ADDRESS     || '0xBd1550ccb0388F88Ef943c0196F439e0586194b3',
        nodeRegistry: process.env.NODE_REGISTRY_ADDRESS       || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    },
    local: {
        rpcUrl:       process.env.LOCAL_RPC_URL                  || 'http://127.0.0.1:8545',
        chainId:      BigInt(31337),
        dcldToken:    process.env.LOCAL_DCLD_TOKEN_ADDRESS        || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
        escrowAddr:   process.env.LOCAL_ESCROW_CONTRACT_ADDRESS   || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
        nodeRegistry: process.env.LOCAL_NODE_REGISTRY_ADDRESS     || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    },
} as const;

const cfg = networkConfig[NETWORK as keyof typeof networkConfig] ?? networkConfig.sepolia;

export const SEPOLIA_RPC          = cfg.rpcUrl;
export const CHAIN_ID             = cfg.chainId;
export const DCLD_TOKEN_ADDR      = cfg.dcldToken;
export const ESCROW_CONTRACT_ADDR = cfg.escrowAddr;
export const NODE_REGISTRY_ADDR   = cfg.nodeRegistry;

let _rpcOverride: string | null = null;
let _dcldAddrOverride: string | null = null;
let _escrowAddrOverride: string | null = null;

export function setRpcUrl(url: string): void {
    _rpcOverride = url || null;
}

export function setDcldTokenAddr(addr: string): void {
    _dcldAddrOverride = addr || null;
}

export function setEscrowAddr(addr: string): void {
    _escrowAddrOverride = addr || null;
}

export function getLiveDcldTokenAddr(): string {
    return _dcldAddrOverride ?? DCLD_TOKEN_ADDR;
}

export function getLiveEscrowAddr(): string {
    return _escrowAddrOverride ?? ESCROW_CONTRACT_ADDR;
}

export interface TokenTransfer {
    txHash: string;
    from: string;
    to: string;
    amount: string;
    blockNumber: number;
    timestamp: number;
}

const ERC20_ABI = [
    'function balanceOf(address owner) view returns (uint256)',
    'function decimals() view returns (uint8)',
];

export function createProvider(): ethers.JsonRpcProvider {
    return new ethers.JsonRpcProvider(_rpcOverride ?? SEPOLIA_RPC);
}

/**
 * Fetch the DCLD ERC-20 balance for an address.
 * Uses decimals() to format the raw value correctly.
 */
export async function getDCLDBalance(
    address: string,
    provider: ethers.JsonRpcProvider,
): Promise<string> {
    const token = new ethers.Contract(getLiveDcldTokenAddr(), ERC20_ABI, provider);
    const [raw, decimals]: [bigint, bigint] = await Promise.all([
        (token as any).balanceOf(address),
        (token as any).decimals(),
    ]);
    return ethers.formatUnits(raw, decimals);
}

/**
 * Fetch the native ETH balance for an address.
 */
export async function getETHBalance(
    address: string,
    provider: ethers.JsonRpcProvider,
): Promise<string> {
    const wei = await provider.getBalance(address);
    return ethers.formatEther(wei);
}

const TRANSFER_TOPIC = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

/**
 * Fetch the 20 most recent DCLD Transfer events involving address (sent + received).
 */
export async function getRecentTransfers(
    address: string,
    provider: ethers.JsonRpcProvider,
): Promise<TokenTransfer[]> {
    const paddedAddr = '0x' + address.toLowerCase().replace('0x', '').padStart(64, '0');
    const latestBlock = await provider.getBlockNumber();
    const fromBlock = Math.max(0, latestBlock - 50000);

    const tokenAddr = _dcldAddrOverride ?? DCLD_TOKEN_ADDR;

    const [inLogs, outLogs] = await Promise.all([
        provider.getLogs({
            address: tokenAddr,
            fromBlock,
            toBlock: 'latest',
            topics: [TRANSFER_TOPIC, null, paddedAddr],
        }),
        provider.getLogs({
            address: tokenAddr,
            fromBlock,
            toBlock: 'latest',
            topics: [TRANSFER_TOPIC, paddedAddr],
        }),
    ]);

    const ZERO_ADDR = '0x' + '0'.repeat(40);
    const all = [...inLogs, ...outLogs]
        .filter(log => ('0x' + (log.topics[1] ?? '').slice(-40)) !== ZERO_ADDR); // exclude mints
    all.sort((a, b) => (b.blockNumber ?? 0) - (a.blockNumber ?? 0));
    const recent = all.slice(0, 20);

    const uniqueBlocks = [...new Set(recent.map(l => l.blockNumber))];
    const blockData = await Promise.all(uniqueBlocks.map(n => provider.getBlock(n)));
    const blockTimes: Record<number, number> = {};
    blockData.forEach(b => { if (b) blockTimes[b.number] = b.timestamp; });

    return recent.map(log => ({
        txHash: log.transactionHash ?? '',
        from: '0x' + (log.topics[1] ?? '').slice(-40),
        to:   '0x' + (log.topics[2] ?? '').slice(-40),
        amount: ethers.formatUnits(BigInt(log.data), 18),
        blockNumber: log.blockNumber ?? 0,
        timestamp: blockTimes[log.blockNumber ?? 0] ?? 0,
    }));
}
