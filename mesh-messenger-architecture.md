# Resilient Mesh Messenger — Multi-Transport DTN Architecture

## 1. Design goal

Bitchat's failure mode: if there's no unbroken chain of Bluetooth-range devices between A and B *right now*, the message dies (or waits, uncarried, for a device to wander by). To fix this seriously, stop thinking of it as "a mesh network" and start thinking of it as a **Delay/Disruption-Tolerant Network (DTN)** — the same class of problem as interplanetary probes talking to Earth, where a link might not exist for hours. The core idea: **messages are bundles that get stored, carried, and forwarded opportunistically across whatever transport is available**, not packets that need an end-to-end live circuit.

Everything below is transport-agnostic on purpose — because your users will have wildly different hardware. A protester has a phone. A journalist has a phone + a LoRa walkie-talkie. A government official might have a satellite uplink. The protocol shouldn't assume any of them.

---

## 2. Layered architecture

```
┌─────────────────────────────────────────┐
│  App layer (Flutter UI, chat/channels)   │
├─────────────────────────────────────────┤
│  Identity & Crypto layer                 │
│  (keypairs, Noise/X3DH sessions,         │
│   signatures, sender-keys for groups)    │
├─────────────────────────────────────────┤
│  Bundle layer (DTN-style)                │
│  (message = signed+encrypted bundle,     │
│   TTL, priority, hop count, dedup ID)    │
├─────────────────────────────────────────┤
│  Routing layer                           │
│  (epidemic / PRoPHET-style forwarding,   │
│   contact history, store quotas)         │
├─────────────────────────────────────────┤
│  Transport abstraction layer             │
│  (pluggable drivers, one interface)      │
├──────┬──────┬──────┬──────┬──────┬───────┤
│ BLE  │ WiFi │ LoRa │ Sat  │ Net  │ USB/   │
│ mesh │Direct│(ext.)│(ext.)│(Nostr│Sneaker-│
│      │/Aware│      │      │/relay│net     │
└──────┴──────┴──────┴──────┴──────┴────────┘
```

The critical decision: **the bundle layer and everything above it never knows which transport moved a message.** A driver's only job is "here's a blob of bytes, deliver it to whoever's listening nearby" — whether "nearby" means 10m of BLE or a satellite footprint covering a continent.

---

## 3. Node roles

Not every device needs to behave the same way.

| Role | Who | Behavior |
|---|---|---|
| **Leaf node** | Ordinary phone | Opportunistic carrier. Stores messages briefly, forwards when it meets peers. Battery/storage constrained, so aggressive pruning. |
| **Relay node** | Dedicated hardware — Raspberry Pi, old Android box, solar-powered field unit | Always-on where possible, more storage, multiple radios (BLE + WiFi + LoRa dongle), acts as a hub other nodes route through. Doesn't need to be trusted — see §6. |
| **Gateway node** | Relay node with internet or satellite backhaul | Bridges the local mesh to the wider network — pushes/pulls bundles via Nostr relays, a custom federated relay server, or a satellite messenger API (Iridium SBD, Garmin inReach-style). This is how a message survives a mesh with zero physical path between sender and receiver. |

Anyone can be a gateway — a phone with cell signal is a gateway too, just an intermittent one. Dedicated relay/gateway boxes just make the network *reliable* instead of purely opportunistic.

---

## 4. Bundle format (the actual message unit)

Borrowing directly from the DTN Bundle Protocol (RFC 9171 / BPv7) rather than reinventing it:

```
Bundle {
  bundle_id:        hash(sender_pubkey || nonce)   // dedup key
  sender_pubkey:    ed25519 public key
  dest_pubkey:      recipient's public key (or group ID)
  created_at:       timestamp
  ttl:              max lifetime (hours/days)
  hop_count:        incremented per relay, capped
  priority:         {low, normal, high}  // e.g. for DMs vs bulk
  payload:          Noise/X3DH-encrypted ciphertext
  signature:         signs everything above
}
```

Key properties:
- **Self-contained.** A bundle carries everything a relay needs to route it — no per-hop session state required, so any relay can pick it up cold.
- **End-to-end encrypted.** Relays (including untrusted strangers' phones, or a government relay box) only ever see ciphertext + routing metadata. They cannot read content. This matters a lot once you assume adversarial or merely nosy relay operators.
- **Dedup by bundle_id.** Since the same message can arrive via five different paths (BLE + a gateway + sneakernet), every node keeps a short-lived seen-set to drop duplicates instead of re-flooding them.
- **TTL + hop cap.** Prevents bundles from living forever and prevents broadcast storms.

---

## 5. Routing: epidemic + informed forwarding

Pure flooding (everyone forwards everything to everyone) works but doesn't scale and drains batteries. Better: a **PRoPHET-style** approach — nodes track a lightweight "delivery predictability" score per peer based on encounter history (who have I met recently, who do they say they've met recently), and prioritize forwarding bundles toward nodes statistically more likely to reach the destination.

Practical rules:
1. On meeting a peer (over any transport), exchange **summary vectors** — just the list of bundle IDs each side has — before exchanging any actual data. Only transfer bundles the other side lacks.
2. Forward higher-priority bundles first when link time is short (BLE contact windows can be seconds).
3. Gateway nodes get forwarded *everything* addressed to pubkeys not seen locally recently — since a gateway's whole job is escaping the local mesh.
4. Storage is a bounded LRU by priority + TTL — cheap phones will evict low-priority old bundles first under pressure.

---

## 6. Transport drivers

| Transport | Range | Bandwidth | Who has it | Notes |
|---|---|---|---|---|
| **BLE mesh** | ~10–100m/hop | Low | Everyone | Bitchat's current layer. Cheap, universal, background-mode limited on iOS. |
| **WiFi Direct / Aware** | ~50–200m | High | Most phones | Good fallback for bigger file/message batches when in the same building/block. iOS support is weaker — lean on MultipeerConnectivity there, which auto-negotiates BLE/WiFi under the hood. |
| **LoRa** (external radio) | 2–15km/hop | Very low (bytes/sec) | Power users, field relay boxes | Needs external hardware (e.g. ESP32 + SX127x) paired to phone over BLE. This is what turns "mesh" into something that covers a city, not a room. You don't need to use it yourself — just support it as a driver so relay-node operators can. |
| **Satellite** (Iridium SBD, inReach-style, or Starlink where available) | Global | Very low to moderate | Gateway operators, officials, journalists in the field | Treated purely as a gateway backhaul, not a peer transport — expensive/slow, so only gateway nodes use it, and only for bundles that can't reach a cheaper route. |
| **Internet relay (Nostr or custom federated relay)** | Global | High | Anyone with data/WiFi | This is what actually gives you global reach without every node needing exotic radios. A gateway posts bundles to relays; the recipient's gateway (or the recipient directly, if online) pulls them. |
| **Sneakernet (USB/file share/QR)** | N/A | N/A | Everyone | Ugly but real — in a total blackout, a bundle can literally be carried on a USB stick or as a QR-code sequence and re-injected elsewhere. Worth supporting as a driver since it's a legitimate DTN "transport" and costs almost nothing to add. |

Because the bundle layer doesn't care which driver moved a message, a single message can hop BLE → a relay's LoRa link → a gateway's satellite uplink → Nostr → the recipient's phone, entirely automatically, with the app just showing "delivered."

---

## 7. Reliability & abuse resistance

This is the part that actually makes it "serious" instead of a toy:

- **Multi-path send.** For important messages, don't rely on one route — broadcast the bundle out every available driver simultaneously and let dedup handle the redundancy. Costs bandwidth, buys reliability.
- **Delivery acknowledgements.** Recipient signs and sends back a small ack bundle over whatever path is available; sender retries with backoff until acked or TTL expires.
- **Sybil/spam resistance.** Since anyone can inject bundles into the mesh, relays should rate-limit per sender pubkey and optionally require a small proof-of-work on bundle creation (cheap for a phone sending a few messages, expensive for a spam firehose).
- **No trust required in relays.** Because everything's E2E encrypted at the bundle layer, a relay node run by a stranger, a company, or yes, a government, can carry your traffic without reading it. Metadata (sender/recipient pubkeys, timing) is still visible to relays though — if you need to hide *that* too, you'd add onion-style routing on top (real cost: latency and complexity; worth flagging as a v2 concern, not v1).
- **Key verification.** Public keys should be verifiable out-of-band (QR code scan on first meeting, like Signal's safety numbers) so the network can't be trivially impersonated the way early Bitchat was.

---

## 8. Example message flow

Sender has no BLE/WiFi path to recipient at all — only a mesh full of strangers' phones nearby, one of which occasionally reaches a relay box with a LoRa link to a gateway with intermittent 3G:

1. Sender's phone creates + signs the bundle, broadcasts it over BLE to nearby peers.
2. A stranger's phone that happens to be a good "encounter-history" match picks it up, carries it as it moves.
3. That phone eventually gets within LoRa range of a fixed relay box.
4. Relay box holds it, and when its 3G gateway link comes up (even briefly), pushes the bundle to a Nostr relay.
5. Recipient's own gateway (or their phone directly, if it ever gets data) polls that Nostr relay, sees a bundle addressed to their pubkey, pulls and decrypts it.
6. Recipient's phone signs an ack, which propagates back the same opportunistic way.

No step required a live end-to-end connection at any point.

---

## 9. Build roadmap (Flutter-realistic, given your stack)

**Phase 1 — protocol core, single transport**
Bundle format, crypto (Noise or libsodium via `sodium_libs` or similar), dedup/store logic, BLE driver only (`flutter_reactive_ble` or `flutter_blue_plus`). This alone already beats Bitchat if your store-and-forward + TTL logic is better than theirs.

**Phase 2 — add WiFi Direct/Aware + MultipeerConnectivity bridge**
Bigger range/bandwidth fallback. iOS needs a platform channel to MultipeerConnectivity since there's no mature Flutter plugin with full parity.

**Phase 3 — gateway support**
Nostr relay push/pull as the internet driver (you already understand this shape from Fleet Manager's edge-function/backend work). This is what gives non-LoRa users real long-range reach for free, since it rides on any internet a gateway phone happens to have.

**Phase 4 — external radio drivers**
LoRa over BLE-paired companion hardware; satellite driver as a thin adapter over whichever provider's API you target. You won't personally test these, but the driver interface should be simple enough that a power user or hardware partner can implement one without touching the core.

**Phase 5 — hardening**
Rate limiting/PoW, safety-number key verification UI, panic-wipe (Bitchat already proved this UX pattern is good), audit of the crypto layer — ideally by someone other than you before anyone relies on it for anything real.

---

## 10. Open trade-offs worth knowing going in

- **Metadata privacy vs. simplicity.** This design hides message content but not who's talking to whom or when, at the relay level. Full metadata privacy (onion routing) is a real added layer of complexity — decide early whether your threat model needs it.
- **Battery cost.** Constant BLE/WiFi scanning and relaying drains phones fast. Bitchat already deals with this; you'll want adaptive duty-cycling (scan aggressively when plugged in/charging, back off otherwise).
- **Storage growth on relay nodes.** Dedicated relay boxes need real quota/eviction policy or they fill up and start dropping high-priority traffic.
- **No security audit = no real trust.** Bitchat learned this the hard way (impersonation bug found within weeks of launch). If this is ever meant for people in actual high-risk situations, budget for external review before calling it "secure."
