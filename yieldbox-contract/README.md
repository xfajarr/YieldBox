# OpenCrate Contracts

Smart-contract suite for the OpenCrate NFT DeFi platform. Every crate is an ERC-721 that owns an ERC-6551 token-bound account linked to a mock DeFi position. The stack is designed for quick MVP iteration: strategies are registered via adapters, accounts interact with DeFi modules, and crate metadata ties everything together.

## Fitur Utama
- **ERC-6551 Accounts** — deterministik melalui registry dan otomatis mengikuti kepemilikan NFT.
- **Crate Strategies** — registry yang memetakan risk tier ke adapter DeFi.
- **Mock DeFi Protocol** — yield accrual bergaya Morpho/Aerodrome untuk simulasi LP/Vault/Lending.
- **Factory + NFT** — orchestrator mint crate, deploy akun, dan menyimpan metadata crate.

## Struktur Direktori
```
src/
  ERC6551Account.sol          # Implementasi akun token-bound (IERC165 + ERC1271)
  ERC6551Registry.sol         # Registry CREATE2 untuk deploy akun ERC-6551
  OpenCrateNFT.sol            # ERC-721 utama + metadata crate
  OpenCrateFactory.sol        # Mint crate & wiring strategi
  adapters/MockYieldAdapter.sol
  mock/MockYieldProtocol.sol
  strategies/OpenCrateStrategyRegistry.sol
  interfaces/IDeFiAdapter.sol
  lib/ERC6551BytecodeLib.sol
docs/
  defi-adapter-overview.md
  erc6551-architecture.md
  opencrate-factory.md
  opencrate-nft.md
```

## Dokumentasi
- [Mock DeFi & Adapter Stack](docs/defi-adapter-overview.md)
- [OpenCrate NFT](docs/opencrate-nft.md)
- [OpenCrate Factory](docs/opencrate-factory.md)
- [ERC-6551 Architecture](docs/erc6551-architecture.md)

## Alur Tingkat Tinggi
1. Admin mendaftarkan strategi pada `OpenCrateStrategyRegistry`.
2. Factory memanggil `mintCrate`:
   - Deploy akun ERC-6551 lewat registry.
   - Mint NFT crate ke user.
   - Simpan metadata (adapter, salt, risk).
3. Token-bound account menjalankan interaksi DeFi menggunakan adapter (deposit, withdraw, claim).
4. Ketika NFT berpindah tangan, akun otomatis mengikuti pemilik baru.

## Setup
```bash
pnpm install        # jika menggunakan script JS/TS
forge install       # ambil dependensi tambahan (opsional, jika belum)
```

## Build & Test
```bash
forge build         # kompilasi kontrak
forge test          # jalankan pengujian (tambahkan test sesuai kebutuhan)
forge fmt           # format solidity
```

> Catatan: pada lingkungan ini `forge` tidak tersedia, jalankan perintah di mesin lokal Anda dengan Foundry terpasang.

## Deploy & Simulasi
- Gunakan `forge script` atau tool lain untuk deploy `MockYieldProtocol`, `MockYieldAdapter`, `OpenCrateStrategyRegistry`, `OpenCrateNFT`, dan `OpenCrateFactory`.
- Pastikan NFT mengatur factory (`setFactory`) dan protocol mengatur adapter (`setAdapter`).

## Lisensi
MIT © OpenCrate Contributors
