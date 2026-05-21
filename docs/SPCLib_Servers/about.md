# SPCLib Halo Servers Overview

The SPCLib **Halo: Custom Edition** servers provide a diverse range of exciting and unique game modes designed to
challenge
players, foster competition, and provide endless fun. Whether you're a fan of strategic team-based gameplay, intense
free-for-all action, or something in between, we have something for everyone.

Here's a quick overview of the current SPCLib **Halo: Custom Edition** servers:

| Game Mode                                               | Description                                                                                                                                                                                                                                                                                                    | Server                 |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------|
| **[Divide & Conquer](servers/divide_and_conquer.md)**   | A dynamic game mode where each team works to recruit opponents after eliminating them, with the game ending when one team is fully converted.                                                                                                                                                                  | **jericraft.net:2304** |
| **[Gun Game](servers/gun_game.md)**                     | Start with basic weapons and upgrade after each kill, aiming to reach the top weapon and claim victory.                                                                                                                                                                                                        | **jericraft.net:2305** |
| **[Kill Confirmed](servers/kill_confirmed.md)**         | Score points by eliminating enemies and collecting their dog tags (skulls), ensuring kills count towards your team's score.                                                                                                                                                                                    | **jericraft.net:2306** |
| **[Melee Attack](servers/melee_attack.md)**             | A mode focused entirely on close combat, where players only use melee attacks to fight their enemies.                                                                                                                                                                                                          | **jericraft.net:2307** |
| **[One In The Chamber](servers/one_in_the_chamber.md)** | Players only have one bullet per life, and must use their wits to outsmart and eliminate opponents without wasting ammo.                                                                                                                                                                                       | **jericraft.net:2308** |
| **[Parkour](servers/parkour.md)**                       | Navigate the EV Jump and training_jump parkour courses, pass through checkpoints, and complete the run in record time. Requires timing, precision, and course knowledge.                                                                                                                                       | **jericraft.net:2309** |
| **[Rooster CTF](servers/rooster_ctf.md)**               | A CTF mode for Slayer (FFA/Team), where players fight to capture a single flag and return it to either the Red or Blue Base to score.                                                                                                                                                                          | **jericraft.net:2310** |
| **[Snipers Dream Team](servers/snipers_dream_team.md)** | A highly modded snipers game mode with unique features and gameplay mechanics.                                                                                                                                                                                                                                 | **jericraft.net:2311** |
| **[Tag](servers/tag.md)**                               | A fast-paced and exciting variation of tag, where players must catch (melee) and eliminate each other in a thrilling chase.                                                                                                                                                                                    | **jericraft.net:2312** |
| **[Uber Racing](servers/uber_racing.md)**               | A fast-paced team racing mode with a twist: players can instantly spawn vehicles or use the **Uber system** to hop into a teammate’s ride. Staying in your vehicle is key, as a race assistant penalizes stragglers on foot. Teamwork, convoys, and vehicle strategy decide who crosses the finish line first. | **jericraft.net:2313** |
| **[Zombies](servers/zombies.md)**                       | A highly modded zombies game mode with unique features and gameplay mechanics.                                                                                                                                                                                                                                 | **jericraft.net:2314** |

---

Each server offers a unique and custom experience, crafted to deliver the best possible gameplay. Whether you're looking
to compete in a classic mode or try something completely new, SPCLib Halo servers are ready for you. Dive into the
action and join us on any of the following servers today!

For more information about each game mode or to connect, check out the individual server pages linked above. Happy
gaming!

---

# Halo Server Scripts

All **SPCLib** servers for **Halo: Custom Edition** are equipped with several custom scripts designed to improve
gameplay, ensure fair play, and enhance the overall server experience. Below is a list of the scripts running on all of
our servers:

| **Script Name**                                                                      | **Description**                                                                                                                                                                               | 
|--------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| 
| 🛡️️ [**Admin Manager**](https://github.com/Chalwk/SPCLib/releases/tag/AdminManager) | A comprehensive drop-in replacement for SAPP's built-in admin system, offering a range of features to help administrators manage players, enforce rules, and maintain a positive environment. |
| 💼 [**Script Manager**](../../sapp/admin/script_manager.lua)                         | Ensures all custom scripts run correctly, providing a smooth and enjoyable gameplay experience.                                                                                               |
| 📝 [**Server Logger**](../../sapp/utility/server_logger.lua)                         | Tracks important events and activities on the server, helping maintain a secure and transparent environment.                                                                                  |
| 🗺️ [**Map Cycle Manager**](../../sapp/utility/mapcycle_manager.lua)                 | Allows administrators to manage map rotations efficiently and switch between classic and custom maps using simple commands.                                                                   |
| 💤 [**AFK System**](../../sapp/admin/afk_system.lua)                                 | Monitors players who are inactive for extended periods, automatically warning and kicking them to prevent disruption to gameplay.                                                             |
| 🔒 [**VPN Blocker**](../../sapp/admin/vpn_blocker.lua)                               | Prevents players from using VPNs to connect to the servers, reducing malicious activity and ensuring legitimate players join.                                                                 |
| 🚫 [**Word Buster**](https://github.com/Chalwk/SPCLib/releases/tag/Word-Buster)      | Filters out inappropriate language and offensive words from chat messages, maintaining a clean and respectful environment.                                                                    |

These scripts work together to provide an environment where players can enjoy fair, secure, and exciting gameplay. We
are always working to improve the community experience, so be sure to check out these features in action on all of our
servers!

Happy playing!

---

# Daily Server Backups

All of our Halo servers are backed up **daily** to ensure that no player progress or server data is ever lost. Our
backup process is automated and runs at regular intervals to capture and store the most recent game data, server
settings, and player statistics. If any unexpected issues occur, we can quickly restore the server to its previous
state, ensuring minimal disruption to gameplay.