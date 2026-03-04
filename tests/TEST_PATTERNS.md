# Colyseus SDK Test Patterns

This document describes the test patterns found in the Colyseus TypeScript SDK that should be ported to the GDScript implementation.

## File Locations in Colyseus Source

Reference: `/Users/sergek/dev/colyseus`

### Key Test Files

1. **Client Tests**: `packages/sdk/test/client.test.ts`
2. **Room Tests**: `packages/sdk/test/room.test.ts`
3. **Integration Tests**: `bundles/colyseus/test/Integration.test.ts`
4. **Room Unit Tests**: `bundles/colyseus/test/Room.test.ts`
5. **HTTP Tests**: `packages/sdk/test/http.test.ts`

### Key Source Files

1. **Client**: `packages/sdk/src/Client.ts`
2. **Room**: `packages/sdk/src/Room.ts`
3. **SchemaSerializer**: `packages/sdk/src/serializer/SchemaSerializer.ts`
4. **Protocol**: `packages/core/src/Protocol.ts`
5. **SharedTypes**: `packages/shared-types/src/Protocol.ts`

---

## 1. Protocol Constants Tests

**Location**: `packages/shared-types/src/Protocol.ts`

### Protocol Codes

```typescript
export const Protocol = {
  // Room-related (10~19)
  JOIN_ROOM: 10,
  ERROR: 11,
  LEAVE_ROOM: 12,
  ROOM_DATA: 13,
  ROOM_STATE: 14,
  ROOM_STATE_PATCH: 15,
  ROOM_DATA_SCHEMA: 16, // DEPRECATED
  ROOM_DATA_BYTES: 17,
  PING: 18,
} as const;
```

### Test Patterns

- Verify protocol codes are in range 0-127 (single byte)
- Verify protocol codes don't conflict
- Test error code ranges (4217, 5200-5260)
- Test close codes (1000-1006, 4000-4010)

### GDScript Test Pattern

```gdscript
func test_protocol_codes_in_byte_range():
    assert_true(Protocol.JOIN_ROOM >= 0 and Protocol.JOIN_ROOM < 128)
    assert_true(Protocol.ERROR >= 0 and Protocol.ERROR < 128)
    # ... etc

func test_protocol_codes_are_unique():
    var codes = [Protocol.JOIN_ROOM, Protocol.ERROR, ...]
    assert_eq(codes.size(), _unique(codes).size())
```

---

## 2. Primitive Encoding/Decoding Tests

**Location**: `packages/core/src/Protocol.ts`, `packages/sdk/src/Room.ts`

### Encoding Functions (from @colyseus/schema)

- `encode.number(buffer, value, iterator)` - Varint encoded number
- `encode.string(buffer, value, iterator)` - Length-prefixed UTF-8 string
- `encode.utf8Write(buffer, value, iterator)` - UTF-8 string with known length
- `encode.boolean(buffer, value, iterator)` - Single byte boolean

### Decoding Functions (from @colyseus/schema)

- `decode.number(buffer, iterator)` - Varint decoded number
- `decode.string(buffer, iterator)` - Length-prefixed UTF-8 string
- `decode.utf8Read(buffer, iterator, length)` - UTF-8 string with known length
- `decode.stringCheck(buffer, iterator)` - Check if next value is string

### Test Patterns

```typescript
// Number encoding/decoding (varint)
test("encode/decode number 0", () => {
    const it = { offset: 0 };
    const buffer = new Uint8Array(16);
    encode.number(buffer, 0, it);
    assert.equal(0, decode.number(buffer, { offset: 0 }));
});

test("encode/decode large number", () => {
    const it = { offset: 0 };
    const buffer = new Uint8Array(16);
    encode.number(buffer, 65535, it);
    assert.equal(65535, decode.number(buffer, { offset: 0 }));
});

// String encoding/decoding
test("encode/decode empty string", () => {
    const it = { offset: 0 };
    const buffer = new Uint8Array(16);
    encode.string(buffer, "", it);
    assert.equal("", decode.string(buffer, { offset: 0 }));
});

test("encode/decode unicode string", () => {
    const it = { offset: 0 };
    const buffer = new Uint8Array(16);
    encode.string(buffer, "Hello 世界", it);
    assert.equal("Hello 世界", decode.string(buffer, { offset: 0 }));
});
```

### Edge Cases to Cover

- Zero values
- Maximum varint values (2^21-1, 2^28-1, 2^35-1, etc.)
- Empty strings
- Unicode strings (emoji, CJK, RTL)
- Buffer overflow scenarios

---

## 3. Varint Encoding Tests

**Location**: Implicit in @colyseus/schema encode.number/decode.number

### Varint Format

- Uses 7 bits per byte, MSB indicates continuation
- Little-endian byte order
- Supports up to 64-bit signed integers

### Test Patterns

```typescript
describe("varint encoding", () => {
    test("single byte values (0-127)", () => {
        for (let i = 0; i < 128; i++) {
            const it = { offset: 0 };
            const buffer = new Uint8Array(16);
            encode.number(buffer, i, it);
            assert.equal(i, decode.number(buffer, { offset: 0 }));
            assert.equal(1, it.offset);
        }
    });

    test("multi-byte values", () => {
        const values = [128, 16383, 2097151, 268435455];
        values.forEach(v => {
            const it = { offset: 0 };
            const buffer = new Uint8Array(16);
            encode.number(buffer, v, it);
            assert.equal(v, decode.number(buffer, { offset: 0 }));
        });
    });

    test("negative numbers", () => {
        const values = [-1, -128, -255, -65535];
        values.forEach(v => {
            const it = { offset: 0 };
            const buffer = new Uint8Array(16);
            encode.number(buffer, v, it);
            assert.equal(v, decode.number(buffer, { offset: 0 }));
        });
    });
});
```

---

## 4. Message Protocol Tests

**Location**: `packages/sdk/src/Room.ts`, `packages/core/src/Protocol.ts`

### Message Structure

All messages follow the pattern:
```
[PROTOCOL_BYTE (1)] [PAYLOAD...]
```

### JOIN_ROOM Message (10)

```
[10] [TOKEN_LEN (varint)] [TOKEN_BYTES] [SERIALIZER_ID_LEN (varint)] [SERIALIZER_ID_BYTES] [HANDSHAKE?]
```

### ERROR Message (11)

```
[11] [CODE (varint)] [MESSAGE_LEN (varint)] [MESSAGE_BYTES]
```

### ROOM_DATA Message (13)

```
[13] [TYPE (string or number varint)] [PAYLOAD (msgpack)]
```

### ROOM_DATA_BYTES Message (17)

```
[17] [TYPE (string or number varint)] [PAYLOAD_LENGTH (varint)] [PAYLOAD_BYTES]
```

### Test Patterns

```typescript
describe("message protocol", () => {
    test("JOIN_ROOM message encoding", () => {
        const token = "reconnection-token";
        const serializerId = "schema";
        const message = getMessageBytes[Protocol.JOIN_ROOM](token, serializerId);

        assert.equal(Protocol.JOIN_ROOM, message[0]);
        // Decode and verify token and serializerId
    });

    test("ERROR message encoding", () => {
        const code = 4217;
        const message = "Invalid payload";
        const encoded = getMessageBytes[Protocol.ERROR](code, message);

        assert.equal(Protocol.ERROR, encoded[0]);
        // Decode and verify code and message
    });
});
```

---

## 5. Room Connection and State Tests

**Location**: `packages/sdk/test/room.test.ts`, `bundles/colyseus/test/Integration.test.ts`

### Room Lifecycle Tests

```typescript
describe("Room", () => {
    describe("onMessage / dispatchMessage", () => {
        test("* should handle if message is not registered", () => {
            const room = new Room("chat");
            room.onMessage("*", (type, message) => {
                assert.equal("something", type);
                assert.equal(1, message);
            });
            room['dispatchMessage']("type", 5);
            room['dispatchMessage']("something", 1);
        });

        test("should handle string message types", () => {
            const room = new Room("chat");
            room.onMessage("type", (message) => {
                assert.equal(5, message);
            });
            room['dispatchMessage']("type", 5);
        });

        test("should handle number message types", () => {
            const room = new Room("chat");
            room.onMessage(0, (message) => {
                assert.equal(5, message);
            });
            room['dispatchMessage'](0, 5);
        });
    });
});
```

### State Change Tests

```typescript
test("should emit state change on JOIN_ROOM", async () => {
    const room = await client.joinOrCreate("room");
    let stateChangeCalled = false;
    room.onStateChange((state) => {
        stateChangeCalled = true;
    });
    assert_true(stateChangeCalled);
});

test("should emit state change on patch", async () => {
    const room = await client.joinOrCreate("room");
    let patchCount = 0;
    room.onStateChange((state) => {
        patchCount++;
    });
    // Modify server state
    await timeout(100);
    assert_true(patchCount > 1);
});
```

---

## 6. Schema State Tests

**Location**: `bundles/colyseus/test/Integration.test.ts`

### Schema Definition Pattern

```typescript
const State = schema({
    number: { type: "number", default: 0 },
    string: { type: "string", default: "" },
    map: { type: "map", of: "number" },
    array: { type: "array", of: "string" },
});
type State = SchemaType<typeof State>;
```

### Initial State Tests

```typescript
test("should receive initial state", async () => {
    const room = await client.joinOrCreate("room");
    assert_not_null(room.state);
    assert_eq(0, room.state.number);
    assert_eq("", room.state.string);
});
```

### Patch Tests

```typescript
test("should receive and apply patches", async () => {
    const room = await client.joinOrCreate("room");
    room.onStateChange((state) => {
        // Verify changes
    });
    // Trigger server change
    await timeout(100);
    assert_true(room.state.number > 0);
});
```

---

## 7. MapSchema Tests

**Location**: Implicit in integration tests

### Test Patterns

```typescript
test("MapSchema add/remove items", async () => {
    const room = await client.joinOrCreate("room");
    room.state.map.set("key1", 100);
    await timeout(50);
    assert_eq(100, room.state.map.get("key1"));

    room.state.map.delete("key1");
    await timeout(50);
    assert_null(room.state.map.get("key1"));
});
```

---

## 8. ArraySchema Tests

**Location**: Implicit in integration tests

### Test Patterns

```typescript
test("ArraySchema push/pop items", async () => {
    const room = await client.joinOrCreate("room");
    room.state.array.push("item1");
    await timeout(50);
    assert_eq(1, room.state.array.size);
    assert_eq("item1", room.state.array.get(0));

    room.state.array.pop();
    await timeout(50);
    assert_eq(0, room.state.array.size);
});
```

---

## 9. Reconnection Tests

**Location**: `bundles/colyseus/test/RoomReconnection.test.ts`

### Test Patterns

```typescript
test("should reconnect and receive patches", async () => {
    const room = await client.joinOrCreate("room");
    const sessionId = room.sessionId;

    // Simulate disconnection
    room.connection.close();

    // Wait for reconnection
    await new Promise(resolve => room.onReconnect(() => resolve()));

    assert_true(room.connection.isOpen);
});
```

---

## 10. Error Handling Tests

**Location**: `packages/sdk/test/client.test.ts`

### Test Patterns

```typescript
test("should handle error message", async () => {
    const room = await client.joinOrCreate("room");
    let errorCode = 0;
    let errorMessage = "";

    room.onError((code, message) => {
        errorCode = code;
        errorMessage = message;
    });

    // Trigger error on server
    await timeout(50);

    assert_not_eq(0, errorCode);
    assert_not_empty(errorMessage);
});
```

---

## 11. Client Connection Tests

**Location**: `packages/sdk/test/client.test.ts`

### URL Parsing Tests

```typescript
test("url string parsing", () => {
    const urls = [
        'ws://localhost:2567',
        'wss://localhost:2567',
        'http://localhost',
        'https://localhost/custom/path',
        '/api',
    ];

    urls.forEach(url => {
        const client = new Client(url);
        assert_not_null(client['settings'].hostname);
        assert_not_null(client['settings'].port);
    });
});
```

---

## Test Data Patterns

### Fixtures

```typescript
// Protocol message fixtures
const JOIN_ROOM_MESSAGE = new Uint8Array([10, 0, 0, 6, 115, 99, 104, 101, 109, 97]);
const ERROR_MESSAGE = new Uint8Array([11, 36, 13, 73, 110, 118, 97, 108, 105, 100, 32, 112, 97, 121, 108, 111, 97, 100]);

// Schema state fixtures
const INITIAL_STATE = { number: 0, string: "" };
const PATCHED_STATE = { number: 42, string: "hello" };
```

### Mock Data

```typescript
// Room data
const ROOM_AVAILABLE = {
    name: "chat",
    roomId: "room-id",
    clients: 0,
    maxClients: 10,
    metadata: { difficulty: "hard" },
};

// Seat reservation
const SEAT_RESERVATION = {
    name: "chat",
    sessionId: "session-id",
    roomId: "room-id",
    reconnectionToken: "reconnection-token",
};
```

---

## Edge Cases to Cover

1. **Buffer overflow** - Encoding values larger than buffer capacity
2. **Empty strings** - Encoding/decoding zero-length strings
3. **Zero values** - Encoding/decoding numeric zeros
4. **Negative numbers** - Proper varint encoding of signed integers
5. **Unicode strings** - Multi-byte UTF-8 characters
6. **Large numbers** - Values requiring multiple varint bytes
7. **Malformed messages** - Invalid protocol bytes or corrupted data
8. **Concurrent patches** - Multiple patches received rapidly
9. **Reconnection during patch** - State changes during reconnection
10. **Message handler not found** - Wildcard handler fallback

---

## Testing Framework Recommendations

For GDScript testing, consider using:

1. **GdUnit4** - Already specified in the implementation plan
2. **Assertion patterns**:
   - `assert_eq(expected, actual)` - Value equality
   - `assert_true(condition)` - Boolean checks
   - `assert_null(value)` - Null checks
   - `assert_not_null(value)` - Non-null checks
   - `assert_signal_emitted(object, signal_name)` - Signal emission

3. **Async testing**:
   - Use `await wait_signal(signal, timeout)` for async operations
   - Use `wait_frames(n)` for simulation timing

4. **Mock objects**:
   - Create mock WebSocket connections for protocol testing
   - Create mock Room instances for state testing
