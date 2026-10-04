use std::collections::HashSet;
use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use cgka_traits::TransportEndpoint;
use futures::executor::block_on;
use marmot_uniffi::{
    ExternalAccountSignerFfi, Marmot, MarmotKitError, RelayPolicyFfi, TimelineMessageQueryFfi,
};
use nostr::{Event, Filter, JsonUtil, Keys, Kind, NostrSigner, PublicKey, UnsignedEvent};
use nostr_relay_builder::prelude::{BoxedFuture, PolicyResult, WritePolicy};
use nostr_relay_builder::{LocalRelay, RelayBuilder};
use nostr_sdk::Client as NostrSdkClient;
use tokio::time::{Instant, sleep, timeout};
use transport_nostr_adapter::{NostrRelayClient, NostrSdkRelayClient};
use transport_nostr_peeler::NostrTransportEvent;

#[derive(Clone)]
struct LocalSigner(Keys);

#[derive(Clone, Debug, Default)]
struct ReplayAudit {
    seen_event_ids: Arc<Mutex<HashSet<String>>>,
    duplicate_submissions: Arc<AtomicUsize>,
}

impl WritePolicy for ReplayAudit {
    fn admit_event<'a>(
        &'a self,
        event: &'a Event,
        _addr: &'a SocketAddr,
    ) -> BoxedFuture<'a, PolicyResult> {
        Box::pin(async move {
            if event.kind == Kind::MlsGroupMessage {
                let event_id = event.id.to_hex();
                let mut seen = self.seen_event_ids.lock().unwrap();
                if !seen.insert(event_id) {
                    self.duplicate_submissions.fetch_add(1, Ordering::SeqCst);
                }
            }
            PolicyResult::Accept
        })
    }
}

impl ExternalAccountSignerFfi for LocalSigner {
    fn public_key(&self) -> Result<String, MarmotKitError> {
        Ok(self.0.public_key().to_hex())
    }

    fn sign_event(&self, unsigned_event_json: String) -> Result<String, MarmotKitError> {
        let unsigned =
            UnsignedEvent::from_json(unsigned_event_json).map_err(|e| MarmotKitError::Runtime {
                details: e.to_string(),
            })?;
        block_on(self.0.sign_event(unsigned))
            .map(|event| event.as_json())
            .map_err(|e| MarmotKitError::Runtime {
                details: e.to_string(),
            })
    }

    fn nip04_encrypt(&self, public_key: String, content: String) -> Result<String, MarmotKitError> {
        let public_key = PublicKey::parse(&public_key).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })?;
        block_on(self.0.nip04_encrypt(&public_key, &content)).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })
    }

    fn nip04_decrypt(
        &self,
        public_key: String,
        encrypted_content: String,
    ) -> Result<String, MarmotKitError> {
        let public_key = PublicKey::parse(&public_key).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })?;
        block_on(self.0.nip04_decrypt(&public_key, &encrypted_content)).map_err(|e| {
            MarmotKitError::Runtime {
                details: e.to_string(),
            }
        })
    }

    fn nip44_encrypt(&self, public_key: String, content: String) -> Result<String, MarmotKitError> {
        let public_key = PublicKey::parse(&public_key).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })?;
        block_on(self.0.nip44_encrypt(&public_key, &content)).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })
    }

    fn nip44_decrypt(&self, public_key: String, payload: String) -> Result<String, MarmotKitError> {
        let public_key = PublicKey::parse(&public_key).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })?;
        block_on(self.0.nip44_decrypt(&public_key, &payload)).map_err(|e| MarmotKitError::Runtime {
            details: e.to_string(),
        })
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn two_external_signers_exchange_mls_message_over_local_relay() {
    let replay_audit = ReplayAudit::default();
    let relay = LocalRelay::new(RelayBuilder::default().write_policy(replay_audit.clone()));
    relay.run().await.unwrap();
    let relay_url = relay.url().await.to_string();
    let temp = tempfile::tempdir().unwrap();
    let alice_keys = Keys::generate();
    let bob_keys = Keys::generate();
    let alice_id = alice_keys.public_key().to_hex();
    let bob_id = bob_keys.public_key().to_hex();
    let relay_urls = vec![relay_url.clone()];
    let observer = NostrSdkClient::builder().build();
    observer.add_relay(&relay_url).await.unwrap();
    observer.connect().await;

    // Give discovery a real, signed NIP-65 and NIP-17 inbox record for each
    // account, as an independently bootstrapped Nostr installation would.
    for keys in [&alice_keys, &bob_keys] {
        let relay_client =
            NostrSdkRelayClient::new(NostrSdkClient::builder().signer(keys.clone()).build());
        for (kind, tag_name) in [(10002, "r"), (10050, "relay")] {
            let event = NostrTransportEvent::new_unsigned(
                keys.public_key().to_hex(),
                kind,
                vec![vec![tag_name.to_owned(), relay_url.clone()]],
                String::new(),
            );
            relay_client
                .publish_event(&[TransportEndpoint(relay_url.clone())], &event, 1)
                .await
                .unwrap();
        }
    }

    let new_client = |name: &str| {
        Marmot::new_with_options(
            temp.path().join(name).to_string_lossy().into_owned(),
            relay_urls.clone(),
            RelayPolicyFfi::AllowLoopback,
            None,
        )
        .unwrap()
    };
    let alice = new_client("alice");
    let bob = new_client("bob");
    alice.start().await.unwrap();
    bob.start().await.unwrap();

    let alice_account = alice
        .login_external_signer(
            alice_id,
            Arc::new(LocalSigner(alice_keys.clone())),
            relay_urls.clone(),
            relay_urls.clone(),
        )
        .await
        .unwrap();
    let bob_account = bob
        .login_external_signer(
            bob_id,
            Arc::new(LocalSigner(bob_keys.clone())),
            relay_urls.clone(),
            relay_urls.clone(),
        )
        .await
        .unwrap();
    assert!(alice_account.external_signing);
    assert!(bob_account.external_signing);

    // The recipient has published its KeyPackage but is offline during group
    // creation. Its Welcome must remain available from the relay after restart.
    bob.shutdown_and_close().await.unwrap();
    drop(bob);

    let group_id = alice
        .create_group(
            alice_account.account_id_hex.clone(),
            "Omarchy Friends MLS prototype".into(),
            vec![bob_account.account_id_hex.clone()],
            None,
        )
        .await
        .unwrap();

    // Exercise the offline gap: Alice sends after the Welcome is published,
    // while Bob is still shut down and has not accepted the group. The relay
    // must retain this epoch's message until Bob processes the Welcome.
    let sent_while_bob_offline = alice
        .send_text(
            alice_account.account_id_hex.clone(),
            group_id.clone(),
            "message sent before Welcome acceptance".into(),
        )
        .await
        .unwrap();
    assert!(
        sent_while_bob_offline.published > 0,
        "MLS message sent while Bob is offline should reach the relay"
    );

    let bob = new_client("bob");
    bob.start().await.unwrap();
    bob.register_external_signer(
        bob_account.account_id_hex.clone(),
        Arc::new(LocalSigner(bob_keys.clone())),
    )
    .await
    .unwrap();

    let bob_group = timeout(Duration::from_secs(20), async {
        loop {
            if let Ok(group) = bob
                .accept_group_invite(bob_account.account_id_hex.clone(), group_id.clone())
                .await
            {
                break group;
            }
            sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .expect("Bob should receive and accept Alice's MLS Welcome");
    let group_route_id = bob_group.nostr_group_id_hex;

    let sent = alice
        .send_text(
            alice_account.account_id_hex.clone(),
            group_id.clone(),
            "hello through external signing".into(),
        )
        .await
        .unwrap();
    assert!(
        sent.published > 0,
        "MLS message should publish to the local relay"
    );

    let deadline = Instant::now() + Duration::from_secs(20);
    loop {
        let page = bob
            .timeline_messages(
                bob_account.account_id_hex.clone(),
                TimelineMessageQueryFfi {
                    group_id_hex: Some(group_id.clone()),
                    limit: Some(20),
                    ..Default::default()
                },
            )
            .unwrap();
        let has_offline_message = page
            .messages
            .iter()
            .any(|message| message.plaintext == "message sent before Welcome acceptance");
        let has_live_message = page
            .messages
            .iter()
            .any(|message| message.plaintext == "hello through external signing");
        if has_offline_message && has_live_message {
            break;
        }
        assert!(
            Instant::now() < deadline,
            "Bob should decrypt both the pre-Welcome offline message and the live MLS message"
        );
        sleep(Duration::from_millis(100)).await;
    }

    alice.shutdown_and_close().await.unwrap();
    bob.shutdown_and_close().await.unwrap();
    drop(alice);
    drop(bob);

    // Reopen both accounts from their original private data roots. The only
    // restored credential is the same external signer; no new identity or
    // group is created during recovery.
    let alice = new_client("alice");
    let bob = new_client("bob");
    alice.start().await.unwrap();
    bob.start().await.unwrap();
    alice
        .register_external_signer(
            alice_account.account_id_hex.clone(),
            Arc::new(LocalSigner(alice_keys)),
        )
        .await
        .unwrap();
    bob.register_external_signer(
        bob_account.account_id_hex.clone(),
        Arc::new(LocalSigner(bob_keys)),
    )
    .await
    .unwrap();

    let recovered_history = bob
        .timeline_messages(
            bob_account.account_id_hex.clone(),
            TimelineMessageQueryFfi {
                group_id_hex: Some(group_id.clone()),
                limit: Some(20),
                ..Default::default()
            },
        )
        .unwrap();
    assert!(
        recovered_history
            .messages
            .iter()
            .any(|message| message.plaintext == "hello through external signing")
    );

    let before_replay: HashSet<String> = observer
        .fetch_events_from(
            [relay_url.clone()],
            Filter::new().kind(Kind::MlsGroupMessage),
            Duration::from_secs(3),
        )
        .await
        .unwrap()
        .iter()
        .map(|event| event.id.to_hex())
        .collect();
    let after_restart = alice
        .send_text(
            alice_account.account_id_hex.clone(),
            group_id.clone(),
            "hello after process restart".into(),
        )
        .await
        .unwrap();
    assert!(after_restart.published > 0);
    let deadline = Instant::now() + Duration::from_secs(20);
    loop {
        let page = bob
            .timeline_messages(
                bob_account.account_id_hex.clone(),
                TimelineMessageQueryFfi {
                    group_id_hex: Some(group_id.clone()),
                    limit: Some(20),
                    ..Default::default()
                },
            )
            .unwrap();
        if page
            .messages
            .iter()
            .any(|message| message.plaintext == "hello after process restart")
        {
            break;
        }
        assert!(
            Instant::now() < deadline,
            "Bob should decrypt a new message after signer/session recovery"
        );
        sleep(Duration::from_millis(100)).await;
    }

    let published_events = observer
        .fetch_events_from(
            [relay_url.clone()],
            Filter::new().kind(Kind::MlsGroupMessage),
            Duration::from_secs(3),
        )
        .await
        .unwrap();
    let replay_event = published_events
        .iter()
        .find(|event| {
            !before_replay.contains(&event.id.to_hex())
                && event.tags.iter().any(|tag| {
                    let parts = tag.as_slice();
                    parts.len() >= 2 && parts[0] == "h" && parts[1] == group_route_id
                })
        })
        .expect("the newly sent MLS group event should be visible on the local relay")
        .clone();
    let _replay_publish_outcome = observer.send_event(&replay_event).await;
    assert!(
        replay_audit.duplicate_submissions.load(Ordering::SeqCst) > 0,
        "the local relay should observe the exact same signed MLS event a second time"
    );
    sleep(Duration::from_secs(1)).await;
    let after_replay = bob
        .timeline_messages(
            bob_account.account_id_hex.clone(),
            TimelineMessageQueryFfi {
                group_id_hex: Some(group_id.clone()),
                limit: Some(20),
                ..Default::default()
            },
        )
        .unwrap();
    assert_eq!(
        after_replay
            .messages
            .iter()
            .filter(|message| message.plaintext == "hello after process restart")
            .count(),
        1,
        "replaying a signed MLS relay event must not duplicate the message"
    );

    alice
        .remove_members(
            alice_account.account_id_hex.clone(),
            group_id.clone(),
            vec![bob_account.account_id_hex.clone()],
        )
        .await
        .unwrap();
    timeout(Duration::from_secs(20), async {
        loop {
            let members = bob
                .group_members(bob_account.account_id_hex.clone(), group_id.clone())
                .await
                .unwrap();
            if members
                .iter()
                .all(|member| member.member_id_hex != bob_account.account_id_hex)
            {
                break;
            }
            sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .expect("Bob should process the MLS removal commit");

    let after_removal = alice
        .send_text(
            alice_account.account_id_hex.clone(),
            group_id.clone(),
            "message after member removal".into(),
        )
        .await
        .unwrap();
    assert!(after_removal.published > 0);
    sleep(Duration::from_secs(2)).await;
    let removed_member_history = bob
        .timeline_messages(
            bob_account.account_id_hex.clone(),
            TimelineMessageQueryFfi {
                group_id_hex: Some(group_id),
                limit: Some(20),
                ..Default::default()
            },
        )
        .unwrap();
    assert!(
        removed_member_history
            .messages
            .iter()
            .all(|message| message.plaintext != "message after member removal")
    );

    alice.shutdown_and_close().await.unwrap();
    bob.shutdown_and_close().await.unwrap();
    observer.shutdown().await;
}
