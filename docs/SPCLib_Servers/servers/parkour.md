# SPCLib-Parkour

## How to Connect

* 🔗 **IP Address:** jericraft.net:2310
* **Client:** Halo Custom Edition

---

## Overview

**EV Jump** is a parkour challenge where players navigate a course full of jumps, ledges, and obstacles. The goal is to
complete the course **as quickly as possible**, passing through checkpoints and finishing the run in record time.
Success depends on **timing, movement precision, and course knowledge**.

### Key Features

* **Checkpoint System:** Players progress through designated checkpoints.
* **Death Limit & Respawn:** If a player dies too many times, their run resets automatically. Players respawn at the *
  *last checkpoint reached**.
* **Timed Runs:** Completion times are tracked for personal bests, map records, and averages. Top 5 rankings are
  displayed per map.
* **Visual Aids:** Start/finish lines and checkpoint markers (flags and oddballs) help guide players.
* **Adjustable Speed:** Running speed varies per map.
* **Anti-Camping:** Players cannot linger on checkpoints without progressing, or they will be reset.
* **Persistent Stats:** Player and map stats are saved and persist across games.

---

## Maps

| Map Name        | Description                                                                         |
|-----------------|-------------------------------------------------------------------------------------|
| `EV_jump`       | Standard EV Jump course with 10 checkpoints, in-order progression.                  |
| `training_jump` | Short training map with 3 checkpoints, in-order progression, slightly faster speed. |

---

## Commands

| Command         | Alias     | Permission | Description                                               |
|-----------------|-----------|------------|-----------------------------------------------------------|
| get_position    | getpos    | 4          | Show your current position and rotation                   |
| goto_checkpoint | goto      | 4          | Teleport to a specific checkpoint                         |
| hard_reset      | hardreset | -1         | Reset all progress and start from the beginning           |
| soft_reset      | softreset | -1         | Respawn at your last checkpoint                           |
| stats           | stats     | -1         | Show top 5 players for the current map and your best time |

---

## Player Progression Notes

* **Course Start:** Cross the start line to begin the run. Timer starts automatically.
* **Checkpoints:** Approach a checkpoint to claim it.
* **Finish Line:** Cross the finish line after reaching all checkpoints to complete the run.
* **Death Tracking:** Players are reset after reaching 10 deaths.
* **Anti-Camp:** Standing in the same spot at a checkpoint too long triggers a reset warning, followed by a course reset
  if ignored.

---