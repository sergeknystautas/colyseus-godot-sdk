# Colyseus SDK Comparison: GDScript SDK vs. Native SDK

An analytical comparison of two Colyseus SDKs for Godot: a pure GDScript implementation and an experimental C-based native implementation using GDExtension.

## Overview

| | **GDScript SDK** | **Native SDK** |
|---|---|---|
| Language | Pure GDScript | C (Zig build system) |
| Godot integration | `.gd` files, no compilation | GDExtension (compiled binary per platform) |
| Core implementation | ~1,700 lines | ~25,500 lines (+ 6,700 Godot integration layer) |
| Test coverage | ~3,800 lines, 299+ tests (2.2:1 test-to-code ratio) | Integration + unit tests, less extensive |
| Dependencies | None (Godot built-ins only) | 5 bundled C libraries (wslay, mbedTLS, cJSON, sds, uthash) |
| Maturity | In production use | 249 commits, actively developed, self-described as experimental |
| Colyseus version | 0.15.x | 0.15.x |

---

## 1. Architecture & Performance

### GDScript SDK

Pure interpreted GDScript running on Godot's VM. All binary decoding (schema fields, msgpack, varints) executes in GDScript loops calling `StreamPeerBuffer`. The architecture is minimal: plain `.gd` files with no compilation step, no native binaries, no build toolchain.

### Native SDK

Compiled C code loaded via GDExtension. Binary decoding runs as native machine code. WebSocket handling uses wslay (a dedicated C WebSocket library) with its own mbedTLS stack rather than delegating to Godot's `WebSocketPeer`.

### Performance implications

The performance gap is most relevant during schema decoding of large state patches. A game with hundreds of entities receiving 30-60Hz updates would decode thousands of binary fields per second. In GDScript, each field decode involves ~5-10 interpreted operations (byte reads, bit shifts, dictionary lookups). In C, the same work compiles to a handful of native instructions — potentially 10-50x faster depending on state complexity.

However, Godot 4.x has improved GDScript performance significantly, and most games are bottlenecked on rendering, physics, or server logic rather than client-side schema decoding. Profiling data would be needed to determine whether the difference matters for any specific game.

---

## 2. Platform Support & Cross-Compilation

### GDScript SDK

Platform support is entirely inherited from Godot. Since the SDK only uses `WebSocketPeer`, `HTTPRequest`, and `StreamPeerBuffer` (all built-in classes), it works everywhere Godot exports to: Desktop (Windows, macOS, Linux), Web (HTML5), iOS, and Android. No extra build steps — exporting a Godot project includes the SDK automatically as `.gd` files. On web, the WebSocket implementation transparently uses the browser's native WebSocket (handled by Godot internally).

### Native SDK

Explicit cross-compilation via Zig produces platform-specific binaries: `.dylib` (macOS), `.so` (Linux), `.dll` (Windows), `.a` (iOS), `.so` (Android NDK), `.wasm` (Web). Each target platform requires a compiled binary bundled in the project's addons directory. The Zig build system makes compilation straightforward (`zig build -Dtarget=aarch64-ios`), but this is a step that must be performed and maintained for every target. Web builds compile to WASM and require Godot's "dlink" web templates — GDExtension web support is still a relatively new Godot feature with some rough edges.

### Tradeoffs

The GDScript SDK requires no build steps — if Godot exports to a platform, the SDK works. The Native SDK requires a compiled binary per target platform, adding build and distribution complexity in exchange for native performance and independence from Godot's networking internals.

### TLS stacks

The Native SDK bundles its own mbedTLS stack with Mozilla CA certificates, separate from Godot's built-in TLS. This means a game using the Native SDK has two TLS implementations: Godot's (for all non-Colyseus networking) and mbedTLS (for Colyseus traffic). The upside is independence from Godot's TLS internals; the downside is two certificate stores and two vulnerability surfaces to maintain. The GDScript SDK uses Godot's built-in TLS exclusively.

---

## 3. Maintainability & Developer Experience

### GDScript SDK

~1,700 lines of pure GDScript. Debugging uses the Godot editor's built-in debugger: breakpoints, stepping, variable inspection. The test suite covers 3,800 lines across 299+ tests. Adding features means writing GDScript with no toolchain changes. Portability across projects: copy the directory or use a git submodule.

### Native SDK

A ~32K-line C codebase (including the Godot integration layer). Debugging crosses the GDExtension boundary — reading C code, rebuilding with Zig, and using native debugging tools rather than the Godot editor. The upstream "may introduce breaking changes at any time" warning means updates can require unexpected adaptation work. Contributing fixes requires C proficiency and understanding the vtable-based schema system. The trade-off: the maintenance burden of the core protocol implementation is someone else's responsibility.

### Schema definition experience

Both SDKs define schemas as GDScript classes:
- **GDScript SDK**: Classes with `_define_field()` calls. Decoding stays in GDScript.
- **Native SDK**: Classes with a `definition()` static method returning field descriptors. Decoding happens in C behind the GDExtension wall.

The developer-facing API is similar; the difference is what happens beneath it.

---

## 4. Feature Completeness

Both SDKs implement the core Colyseus 0.15.x binary protocol. Detailed comparison:

| Feature | GDScript SDK | Native SDK |
|---|---|---|
| JOIN/LEAVE/ERROR | Yes | Yes |
| ROOM_STATE (full sync) | Yes | Yes |
| ROOM_STATE_PATCH (delta) | Yes | Yes |
| ROOM_DATA (messages) | Yes | Yes |
| ROOM_DATA_BYTES (binary) | Yes | Yes |
| ROOM_DATA_SCHEMA (16) | N/A (deprecated) | N/A (deprecated) |
| PING (latency measurement) | Yes | Yes |
| HTTP matchmaking | Yes | Yes |
| Reconnection tokens | Yes | Yes |
| Authentication API | No | Yes (dedicated auth module) |
| Schema primitives | All types | All types |
| Nested refs | Yes | Yes |
| ArraySchema | Yes | Yes |
| MapSchema | Yes | Yes |
| SetSchema | Yes | No |
| CollectionSchema | Yes (generic fallback) | No |
| Schema change callbacks | listen, on_add, on_remove, on_change | listen, on_add, on_remove, on_change |
| Polymorphic schemas (TYPE_ID) | Yes | Yes |

### Notes

- **HANDSHAKE (9)** was listed in the native SDK as a local constant but is not a real Colyseus protocol message. Handshake data (schema reflection) is embedded as trailing bytes in the JOIN_ROOM (10) payload. Both SDKs handle JOIN_ROOM correctly.
- **ROOM_DATA_SCHEMA (16)** is marked `DEPRECATED` in the official Colyseus protocol. The server no longer sends it. Neither SDK needs to implement it for new development.

### Remaining gaps

**GDScript SDK** is missing a dedicated auth module. This is a straightforward addition if needed.

**Native SDK** is missing SetSchema and CollectionSchema. If a server uses `SetSchema`, the Native SDK cannot decode it. This is a harder gap: it requires changes to the C collection system rather than adding a message handler. That said, `SetSchema` usage is relatively rare in practice.

---

## 5. Risk Assessment

| Risk | GDScript SDK | Native SDK |
|---|---|---|
| **Performance ceiling** | GDScript decoding could bottleneck at very high entity counts / update rates. Mitigable by profiling and selectively optimizing hot paths. | Not a concern — C decoding is fast. |
| **Colyseus protocol changes** | Must be tracked and implemented manually. | Handled by upstream maintainers, but "breaking changes at any time" means updates can be disruptive. |
| **Godot version upgrades** | Low risk. GDScript and `WebSocketPeer` are stable across Godot 4.x. | Medium risk. GDExtension API can change between Godot versions, requiring rebuilds and potentially code changes. |
| **Dual TLS stacks** | Not applicable — uses Godot's networking throughout. | Bundled mbedTLS runs alongside Godot's TLS, creating two stacks to maintain. |
| **Build/deploy complexity** | None — `.gd` files are included in any Godot export. | Requires compilation for every target platform and maintaining the Zig toolchain. |
| **Bus factor** | Small codebase (1,700 lines) is easy to hand off or onboard new contributors to. | Dependent on upstream maintainer(s). The project is active but marked experimental. |
| **Web export reliability** | Reliable — Godot's HTML5 export handles WebSocket natively. | GDExtension WASM via dlink templates is newer and less proven in production. |

---

## 6. When to Use Which

### GDScript SDK fits when:

- The game targets multiple platforms (especially web) and minimizing build complexity matters.
- The team works primarily in GDScript and wants to debug the networking stack in the Godot editor.
- State sync volume is moderate — typical lobby-based games, turn-based games, or real-time games with dozens (not hundreds) of entities at standard update rates.
- The project does not need Colyseus authentication (or is willing to add a simple HTTP auth layer).

### Native SDK fits when:

- The game has high entity counts or high-frequency state updates where schema decoding performance is critical (and profiling confirms it).
- The team is comfortable with C toolchains, Zig builds, and cross-compilation for each target platform.
- Colyseus authentication is needed out of the box.
- The game targets only desktop platforms (where GDExtension is mature), or the team has experience shipping GDExtension WASM builds.

### Hybrid approach:

Start with the GDScript SDK. If profiling a specific game reveals schema decoding as a bottleneck, write a targeted GDExtension for just the decode hot path (~200 lines of C) rather than adopting the entire Native SDK.
