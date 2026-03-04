import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { createServer, IncomingMessage, ServerResponse } from "http";

import { StateRoom } from "./rooms/StateRoom";
import { EchoRoom } from "./rooms/EchoRoom";
import { ErrorRoom } from "./rooms/ErrorRoom";

const PORT = 2570;

const httpServer = createServer((req: IncomingMessage, res: ServerResponse) => {
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }
  res.writeHead(404);
  res.end();
});

const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define("state", StateRoom);
gameServer.define("echo", EchoRoom);
gameServer.define("error", ErrorRoom);

httpServer.listen(PORT, () => {
  console.log(`[TestServer] Colyseus listening on port ${PORT}`);
  console.log(`[TestServer] Health: http://localhost:${PORT}/healthz`);
});
