import { Schema, type, MapSchema, ArraySchema } from "@colyseus/schema";

// Nested schema for StateRoom's player map
export class PlayerSchema extends Schema {
  @type("string") sessionId: string = "";
  @type("string") name: string = "";
  @type("float32") x: number = 0;
}

// StateRoom schema: exercises primitives, collections, nested schemas
export class StateRoomSchema extends Schema {
  @type("uint8") scoreU8: number = 0;
  @type("int32") scoreI32: number = 0;
  @type("float32") speed: number = 0;
  @type("string") label: string = "";
  @type("boolean") active: boolean = false;
  @type({ map: PlayerSchema }) players = new MapSchema<PlayerSchema>();
  @type(["string"]) tags = new ArraySchema<string>();
}

// EchoRoom schema: minimal, just needs to exist
export class EchoRoomSchema extends Schema {
  @type("uint8") placeholder: number = 0;
}

// ErrorRoom schema: minimal
export class ErrorRoomSchema extends Schema {
  @type("uint8") placeholder: number = 0;
}
