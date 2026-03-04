import { Room, Client } from "colyseus";
import { EchoRoomSchema } from "../schemas";

export class EchoRoom extends Room<EchoRoomSchema> {
  onCreate() {
    this.setState(new EchoRoomSchema());

    this.onMessage("echo", (client, data) => {
      client.send("echo", data);
    });
  }

  onJoin(_client: Client) {}
  onLeave(_client: Client) {}
}
