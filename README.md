# Colyseus GDScript SDK

A pure GDScript client library for [Colyseus](https://colyseus.io/) 0.15.x multiplayer framework, targeting Godot 4.x.

No native binaries, no compilation — just `.gd` files that work on every Godot export target.

> Considering the [native C SDK](https://github.com/colyseus/colyseus-native-sdk) instead? See [COMPARISON.md](COMPARISON.md) for a detailed analysis.

## Features

- Full Colyseus binary protocol (JOIN, LEAVE, ROOM_STATE, ROOM_STATE_PATCH, ROOM_DATA, ROOM_DATA_BYTES, ERROR, PING)
- Complete `@colyseus/schema` binary decoding (all primitives, nested refs, polymorphic types)
- Collection types: ArraySchema, MapSchema, SetSchema, CollectionSchema
- Change callbacks: `listen()` on schema properties, `on_add()`/`on_remove()`/`on_change()` on collections, `on_change()` on schemas
- Ping latency measurement: `ping()` / `get_latency()`
- HTTP matchmaking (joinOrCreate) and reconnection with tokens
- Zero dependencies — uses only Godot built-in classes (`WebSocketPeer`, `HTTPRequest`, `StreamPeerBuffer`)
- Works on Desktop, Web (HTML5), iOS, and Android

## Installation

### Godot Asset Library

1. Open the Godot editor
2. Go to the **AssetLib** tab
3. Search for **Colyseus GDScript SDK**
4. Click **Download**, then **Install**

### Git submodule

```bash
git submodule add https://github.com/<org>/colyseus-godot-sdk .deps/colyseus-sdk
ln -s ../../.deps/colyseus-sdk/addons/colyseus addons/colyseus
```

### Manual copy

Clone this repository and copy the `addons/colyseus/` directory into your project's `addons/` folder.

## Setup

After installation, register the autoload singleton:

1. Open **Project > Project Settings > Autoload**
2. Add a new autoload:
   - **Path:** `res://addons/colyseus/src/client/ColyseusClient.gd`
   - **Name:** `ColyseusSDK`

## Usage

### Connecting and joining a room

```gdscript
var client := ColyseusClient.new()
add_child(client)

# Connect to server (validates HTTP reachability)
client.connect_to_server("ws://localhost:2567")
await client.connected

# Join a room with matchmaking
var room := client.join("my_room", {"name": "Player1"})
```

Or use the shorthand:

```gdscript
client.connect_and_join("ws://localhost:2567", "my_room", {"name": "Player1"})
```

### Defining and receiving state

```gdscript
# Define a schema matching the server's @colyseus/schema structure
class_name PlayerState extends Schema

func _init():
    _define_field(0, "x", "float32")
    _define_field(1, "y", "float32")
    _define_field(2, "name", "string")
```

```gdscript
class_name GameState extends Schema

var players: MapSchema

func _init():
    players = MapSchema.new()
    _define_field(0, "players", "map")
    register_schema_type("PlayerState", func(): return PlayerState.new())
```

```gdscript
# Assign state schema to the room before join completes
var state := GameState.new()
room.set_state(state)

# Listen for state changes
room.state_changed.connect(func(changes):
    for change in changes:
        print("Changed: %s" % change)
)

# Listen to specific properties
state.listen("tick", func(value, previous):
    print("Tick: %s -> %s" % [previous, value])
)

# Listen to collection changes
state.players.on_add(func(player, key):
    print("Player added: %s" % key)
)

state.players.on_change(func(player, key):
    print("Player changed: %s" % key)
)

# Listen for any property change on a schema (no-arg callback)
state.on_change(func():
    print("State changed")
)
```

### Sending and receiving messages

```gdscript
# Send a message
room.send("move", {"x": 100, "y": 200})

# Receive messages
room.message_received.connect(func(type, data):
    print("Message: %s %s" % [type, data])
)
```

### Reconnection

```gdscript
# Save the token (e.g., to a file) before disconnecting
var token := room.get_reconnection_token()

# Later, reconnect with the saved token
var room := client.reconnect(token)
```

### Disconnecting

```gdscript
room.leave()          # Consented leave
client.close_connection()  # Close WebSocket and clean up
```

## Signals

### ColyseusClient
| Signal | Arguments | Description |
|---|---|---|
| `connected` | — | Server reachable via HTTP |
| `disconnected` | — | WebSocket closed |
| `error` | `code: int, message: String` | Connection or protocol error |

### ColyseusRoom
| Signal | Arguments | Description |
|---|---|---|
| `joined` | — | Room join confirmed, initial state received |
| `left` | `code: int, reason: String` | Left the room |
| `error_received` | `code: int, message: String` | Server-sent error |
| `state_changed` | `changes: Array` | State updated (full or patch) |
| `message_received` | `type, data` | Room message received |
| `data_bytes_received` | `data: PackedByteArray` | Raw binary data received |

## Project Structure

```
colyseus-godot-sdk/
├── addons/colyseus/                   # SDK (this is what gets installed)
│   ├── src/
│   │   ├── client/ColyseusClient.gd  # Connection, matchmaking, message dispatch
│   │   ├── protocol/
│   │   │   ├── Protocol.gd           # Protocol constants
│   │   │   ├── Decoder.gd            # Binary/msgpack decoding
│   │   │   └── Encoder.gd            # Binary/msgpack encoding
│   │   ├── room/
│   │   │   ├── Room.gd               # Room lifecycle, state, callbacks
│   │   │   └── RoomState.gd          # Room state wrapper
│   │   └── schema/
│   │       ├── Schema.gd             # Base schema with binary decode
│   │       └── types/
│   │           ├── ArraySchema.gd    # Ordered indexed collection
│   │           ├── MapSchema.gd      # Key-value collection
│   │           ├── SetSchema.gd      # Unique value collection
│   │           └── CollectionSchema.gd
│   └── LICENSE
├── tests/                             # Dev-only (not shipped via Asset Library)
│   ├── unit/                          # 304+ unit tests (GdUnit4)
│   ├── integration/                   # Live server integration tests
│   └── test_server/                   # Docker + Node.js Colyseus test server
├── examples/
│   └── minimal_client.gd
├── COMPARISON.md                      # GDScript SDK vs. Native SDK analysis
└── README.md
```

## License

MIT
