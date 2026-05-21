# SPCLib Halo Servers Overview

The SPCLib **Halo: Custom Edition** servers provide a range of exciting and unique game modes. Here's a quick overview of the servers:

| Game Mode                                               | Description                                                                                                                                                                                                                                                                                                    | Server               |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| **[Divide & Conquer](servers/divide_and_conquer.md)**   | A dynamic game mode where each team works to recruit opponents after eliminating them, with the game ending when one team is fully converted.                                                                                                                                                                  | `jericraft.net:2304` |
| **[Gun Game](servers/gun_game.md)**                     | Start with basic weapons and upgrade after each kill, aiming to reach the top weapon and claim victory.                                                                                                                                                                                                        | `jericraft.net:2305` |
| **[Kill Confirmed](servers/kill_confirmed.md)**         | Score points by eliminating enemies and collecting their dog tags (skulls), ensuring kills count towards your team's score.                                                                                                                                                                                    | `jericraft.net:2306` |
| **[Melee Attack](servers/melee_attack.md)**             | A mode focused entirely on close combat, where players only use melee attacks to fight their enemies.                                                                                                                                                                                                          | `jericraft.net:2307` |
| **[One In The Chamber](servers/one_in_the_chamber.md)** | Players only have one bullet per life, and must use their wits to outsmart and eliminate opponents without wasting ammo.                                                                                                                                                                                       | `jericraft.net:2308` |
| **[Parkour](servers/parkour.md)**                       | Navigate the EV Jump and training_jump parkour courses, pass through checkpoints, and complete the run in record time. Requires timing, precision, and course knowledge.                                                                                                                                       | `jericraft.net:2309` |
| **[Rooster CTF](servers/rooster_ctf.md)**               | A CTF mode for Slayer (FFA/Team), where players fight to capture a single flag and return it to either the Red or Blue Base to score.                                                                                                                                                                          | `jericraft.net:2310` |
| **[Snipers Dream Team](servers/snipers_dream_team.md)** | A highly modded snipers game mode with unique features and gameplay mechanics.                                                                                                                                                                                                                                 | `jericraft.net:2311` |
| **[Tag](servers/tag.md)**                               | A fast-paced and exciting variation of tag, where players must catch (melee) and eliminate each other in a thrilling chase.                                                                                                                                                                                    | `jericraft.net:2312` |
| **[Uber Racing](servers/uber_racing.md)**               | A fast-paced team racing mode with a twist: players can instantly spawn vehicles or use the **Uber system** to hop into a teammate’s ride. Staying in your vehicle is key, as a race assistant penalizes stragglers on foot. Teamwork, convoys, and vehicle strategy decide who crosses the finish line first. | `jericraft.net:2313` |
| **[Zombies](servers/zombies.md)**                       | A highly modded zombies game mode with unique features and gameplay mechanics.                                                                                                                                                                                                                                 | `jericraft.net:2314` |

Each server offers a unique and custom experience, crafted to deliver the best possible gameplay. Whether you're looking
to compete in a classic mode or try something completely new, SPCLib Halo servers are ready for you. Dive into the
action and join us on any of the following servers today!

For more information about each game mode or to connect, check out the individual server pages linked above. Happy
gaming!

---

## Ban Appeals

If you believe you have been banned in error from the **SPCLib Discord or Halo servers**, you may submit a formal appeal:

* [Submit a Ban Appeal][ban_appeal_template]

---

# Halo Server Scripts

All **SPCLib** servers for **Halo: Custom Edition** are equipped with several custom scripts designed to improve
gameplay, ensure fair play, and enhance the overall server experience. Below is a list of the scripts running on all of
our servers:

| Script Name                         | Description                                                                                                                                                                                                                                                                                                                                                                                   |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Admin Manager [admin_manager]       | Drop-in replacement for SAPP's admin system. Helps admins manage players, enforce rules, and maintain a positive environment.                                                                                                                                                                                                                                                                 |
| AFK System [afk_system]             | Monitors inactive players; auto-warns and kicks to prevent gameplay disruption.                                                                                                                                                                                                                                                                                                               |
| Anti Aimbot [anti_aimbot]           | Multi-layered anti-cheat detecting unnatural aiming via angle thresholds, velocity analysis, trajectory prediction, weapon-specific profiling, environmental awareness, camouflage detection, and robotic pattern recognition. Auto-enforces moderation on confirmation.                                                                                                                      |
| Halo Discord Bot [halo_discord_bot] | Java app connecting Halo servers (SAPP/Phasor) to Discord via JDA. Features: real-time event notifications (chat, deaths, joins, etc.), bidirectional chat, executing server commands from Discord, multiple server support, per-server Discord channels, configurable embeds, secure remote hosting with auth/IP whitelisting, TCP auto-reconnect, and slash commands (/game_status, /halo). |
| Server Logger [server_logger]       | Tracks important server events and activities for security and transparency.                                                                                                                                                                                                                                                                                                                  |
| VPN Blocker [vpn_blocker]           | Blocks VPN connections to reduce malicious activity and ensure legitimate players.                                                                                                                                                                                                                                                                                                            |
| Word Buster [word_buster]           | Filters inappropriate/offensive chat language for a clean, respectful environment.                                                                                                                                                                                                                                                                                                            |

---

[admin_manager]: ../../sapp/admin/admin_manager.lua

[afk_system]: ../../sapp/admin/afk_system.lua

[anti_aimbot]: https://github.com/Chalwk/SPCLib/blob/master/sapp/admin/anti_aimbot.lua

[ban_appeal_template]: https://github.com/Chalwk/SPCLib/issues/new?template=BAN_APPEAL.yaml

[bans]: https://chalwk.github.io/SPCLib/docs/SPCLib_Servers/bans

[server_logger]: ../../sapp/utility/server_logger.lua

[vpn_blocker]: ../../sapp/admin/vpn_blocker.lua

[word_buster]: https://github.com/Chalwk/SPCLib/releases/tag/wordbuster
