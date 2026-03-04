import { Room, Client } from "colyseus";
import { ErrorRoomSchema } from "../schemas";

export class ErrorRoom extends Room<ErrorRoomSchema> {
  onCreate() {
    this.setState(new ErrorRoomSchema());

    // "kick" message: disconnect the client after a short delay
    this.onMessage("kick", (client) => {
      client.leave(4201); // WS_SERVER_DISCONNECT
    });
  }

  async onAuth(_client: Client, options: any) {
    // Reject if options.reject is truthy
    if (options?.reject) {
      throw new Error("Auth rejected for testing");
    }
    return true;
  }

  onJoin(_client: Client) {}
  onLeave(_client: Client) {}
}
