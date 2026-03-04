import { Room, Client } from "colyseus";
import { StateRoomSchema, PlayerSchema } from "../schemas";

export class StateRoom extends Room<StateRoomSchema> {
  onCreate() {
    this.setState(new StateRoomSchema());

    // Set initial primitive values
    this.state.scoreU8 = 10;
    this.state.scoreI32 = -42;
    this.state.speed = 3.14;
    this.state.label = "hello";
    this.state.active = true;
    this.state.tags.push("alpha");
    this.state.tags.push("beta");

    // "mutate" message: changes fields to produce a real ROOM_STATE_PATCH
    this.onMessage("mutate", (client, data) => {
      if (data.scoreU8 !== undefined) this.state.scoreU8 = data.scoreU8;
      if (data.label !== undefined) this.state.label = data.label;
      if (data.active !== undefined) this.state.active = data.active;
    });
  }

  onJoin(client: Client) {
    const player = new PlayerSchema();
    player.sessionId = client.sessionId;
    player.name = `Player-${client.sessionId.slice(0, 4)}`;
    player.x = 100;
    this.state.players.set(client.sessionId, player);
  }

  async onLeave(client: Client, consented: boolean) {
    try {
      if (!consented) {
        // Allow reconnection for 10 seconds on unexpected disconnects
        await this.allowReconnection(client, 10);
        return; // Client reconnected — keep their player
      }
    } catch {
      // Reconnection timed out or failed
    }
    this.state.players.delete(client.sessionId);
  }
}
