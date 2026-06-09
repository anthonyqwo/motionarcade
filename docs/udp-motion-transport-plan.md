# UDP Motion Transport Plan

## Goal

Reduce trail latency and WebSocket backpressure by moving high-frequency motion
trail packets to UDP while keeping reliable room control messages on WebSocket.

## Current Implementation Status

- Phase 1 host rendering baseline is implemented.
- First UDP transport slice is implemented:
  - WebSocket sends `transportConfig` after `join`.
  - Host opens a UDP socket for `motionTrail`.
  - Controller sends trail packets over UDP when configured.
  - Controller falls back to WebSocket trail packets if UDP is unavailable.
  - Saber receives UDP trail events while keeping feedback on WebSocket.
- Packet format is compact JSON for now; binary packing remains a later
  optimization after measuring real device latency.

## Current Bottleneck

- `motionTrail` is sent as JSON over WebSocket at active rates around 20-30Hz.
- WebSocket is reliable and ordered, so a delayed packet can hold newer trail
  packets behind it.
- Trail rendering needs the newest controller pose more than guaranteed delivery
  of every old sample.
- Join, disconnect, feedback, calibration, and scoring events still need reliable
  delivery.

## Transport Split

| Channel | Transport | Events | Reason |
| --- | --- | --- | --- |
| Control | WebSocket | `join`, `disconnect`, `calibrate`, `slash`, `shoot`, `feedback` | Ordered and reliable semantics matter. |
| Motion stream | UDP | `motionTrail` only | Latest samples matter more than replaying old packets. |

## Phase 1: Host Rendering Baseline

- Keep the current WebSocket protocol working.
- Bound host-side trail storage with `TrailPointBuffer`.
- Prune expired trail samples independently from network arrival.
- Reduce `TrailRenderer` per-frame work:
  - skip sorting when points are already appended in timestamp order;
  - cap points painted per player;
  - lower interpolation density;
  - reuse `Paint` objects inside segment loops.

Success criteria:

- Room preview and Saber arena remain responsive while a phone streams trail.
- Trail count does not grow without bound.
- Existing WebSocket tests continue to pass.

## Phase 2: UDP Packet Shape

Add a compact UDP packet for trail samples:

```json
{
  "v": 1,
  "kind": "trail",
  "room": "room-id",
  "playerId": "p1",
  "seq": 1284,
  "sentAt": 1710000000000,
  "referenceTimestamp": 1710000000000,
  "samples": [
    {"tMs": 0, "x": 0.12, "y": 0.44, "s": 3.2}
  ]
}
```

Rules:

- `seq` is monotonic per player.
- Host drops packets with a sequence older than the latest accepted packet for
  that player, allowing limited out-of-order tolerance.
- Host never waits for missing UDP packets.
- Host normalizes accepted packets onto the host clock before adding them to
  `TrailPointBuffer`.
- Keep JSON initially for speed of implementation; consider binary packing only
  after measurement.

## Phase 3: Discovery And Handshake

Use WebSocket for UDP setup:

1. Host starts WebSocket room server.
2. Host also binds a UDP socket on a nearby port, for example `wsPort + 1`.
3. Controller connects to WebSocket and sends `join`.
4. Host replies with a reliable `transportConfig` message:
   - UDP host;
   - UDP port;
   - room token;
   - desired trail rate;
   - max batch size.
5. Controller starts sending UDP `motionTrail` packets.
6. Host records the sender IP/port for each `playerId`.
7. WebSocket remains open for control and feedback.

## Phase 4: Reliability Policy

UDP trail stream:

- Drop stale packets.
- Drop malformed packets.
- Keep only the newest `retention` window in `TrailPointBuffer`.
- Optionally send a low-rate WebSocket fallback trail if no UDP packet arrives
  for 500ms.

WebSocket control stream:

- Keep existing reliable event handling.
- Continue sending haptic feedback over WebSocket.
- Use WebSocket disconnect as the authoritative player disconnect signal.

## Phase 5: Implementation Files

New files:

- `lib/network/udp_motion_server_service_io.dart`
- `lib/network/udp_motion_client_service_io.dart`
- `lib/network/udp_motion_packet_codec.dart`
- `test/udp_motion_packet_codec_test.dart`

Likely edits:

- `lib/network/room_host_info.dart`: include optional UDP port.
- `lib/shared/models/motion_event.dart`: add `TransportConfigEvent`.
- `lib/network/motion_event_codec.dart`: encode/decode `transportConfig`.
- `lib/desktop/room_page.dart`: start/stop UDP server with the room server.
- `lib/controller/controller_home_page.dart`: start UDP streaming after config.
- `lib/controller/motion_trail_streamer.dart`: send trail through a transport
  callback so WebSocket and UDP can be swapped without touching sensor logic.

## Phase 6: Measurement

Add debug counters:

- UDP packets received per second.
- UDP packets dropped as stale.
- Average host receive delay from `sentAt`.
- Trail points rendered.
- Frame build/raster timing in the room preview and Saber arena.

Target:

- active trail transport at 30Hz with no visible backlog;
- host receive delay under 50ms on local Wi-Fi;
- no noticeable frame stutter during repeated slashes.

## Rollback

Keep WebSocket `motionTrail` as a feature flag fallback until UDP has been
tested on macOS, iOS, and Android. If UDP bind or send fails, the controller
continues with the existing WebSocket path.
