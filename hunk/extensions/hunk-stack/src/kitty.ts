import { spawn } from "node:child_process";

/** Moves kitty's focus one window over; resolves to an error message, or null. */
export type MoveWindow = (direction: "left" | "right") => Promise<string | null>;

/**
 * Runs kitty's `neighboring_window` on this window over remote control, so a key kitty
 * passes through to hunk can still leave it, as smart-splits does from nvim. It needs kitty's socket: without
 * `KITTY_LISTEN_ON`, `kitten @` talks over the tty, which the renderer owns.
 */
export function kittyMoveWindow(env: NodeJS.ProcessEnv = process.env): MoveWindow {
  return (direction) =>
    new Promise((resolve) => {
      if (!env.KITTY_WINDOW_ID || !env.KITTY_LISTEN_ON) {
        resolve(null);
        return;
      }
      const child = spawn("kitten", ["@", "action", "--self", "neighboring_window", direction], {
        stdio: ["ignore", "ignore", "pipe"],
      });
      let stderr = "";
      child.stderr.on("data", (chunk) => (stderr += chunk));
      child.on("error", (error) => resolve(`stack: kitten @ action failed: ${error.message}`));
      child.on("close", (code) =>
        resolve(code === 0 ? null : `stack: kitten @ action failed: ${stderr.trim() || `exit ${code}`}`),
      );
    });
}
