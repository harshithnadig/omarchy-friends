# MLS session experiment

This is an isolated protocol-integration test, not the Friends runtime transport.
It pins MDK to commit `fcc85edd8dbd07c8293c899ee52230f72c54c897` and proves
that the supported UniFFI external-signer contract can drive two accounts
through relay discovery, MLS group setup, Welcome acceptance, message send, and
recipient decryption using a loopback-only local relay.

Bob is fully stopped while Alice creates the group. Bob then reopens the same
account and receives the pending Welcome from the relay before joining.

The test closes and reopens both account runtimes, restores the same external
signers, verifies persisted history, and retransmits an identical signed MLS
relay event without creating a duplicate timeline row. For removal, it copies
Bob's account only after closing the runtime, then delivers the exact
post-removal ciphertext through a separate loopback relay to that stale
pre-removal session; the stale timeline does not expose the plaintext. The
test does not call a lower-level decrypt API with the raw ciphertext and is not
a formal cryptographic audit.

The local test host logged SQLCipher `mlock()` failures (`ENOMEM`) while still
passing the protocol flow. Memory locking is therefore not established by this
experiment and must be validated on the target runtime before production use.

The test creates fresh identities in memory, uses a test-only in-memory secret
store, and writes only temporary account databases. It needs no desktop keyring
or Secret Service. It does not read the installed Friends identity, write
Friends state, advertise an MLS capability, or change the existing NIP-17
transport. Production enablement still needs reordered Welcome behavior, downgrade prevention, real-relay
interoperation, identity migration/recovery from existing Friends
profiles, and UI/runtime integration.

Run with:

```sh
cd native/mls-session-experiment
cargo test --locked
```

The crate pins Rust 1.97.1 to match MDK. Rustup will select the pinned toolchain
when run from this directory. The crate is deliberately independent from the
Python/Quickshell plugin build.
