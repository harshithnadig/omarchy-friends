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

## Isolated Linux Python bridge build

The pinned UniFFI library can also be packaged for evaluation with the same
external-signer API used by the protocol experiment:

```sh
scripts/build-mls-python-bridge.sh
```

The script writes the generated Python module, native shared library, SHA-256,
and build provenance under `/tmp/omarchy-friends-mls-python-bridge/`. It builds
MDK commit `fcc85edd8dbd07c8293c899ee52230f72c54c897` for Linux x86_64, uses the
MDK-pinned Rust toolchain, import-checks the generated API, and runs an isolated
two-client MLS Welcome/message exchange over a localhost relay using temporary
Friends identities and an in-memory secret store. Clang is needed
on hosts where GCC emits an invalid SQLCipher TLS relocation for this shared
library. Provide another output directory as the script's first argument.

This is packaging groundwork only: Friends does not load the bridge, does not
advertise MLS, and continues to use its existing message transport. The binary
is not checked into the plugin or downloaded at runtime.

The crate pins Rust 1.97.1 to match MDK. Rustup will select the pinned toolchain
when run from this directory. The crate is deliberately independent from the
Python/Quickshell plugin build.
