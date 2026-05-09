<div align="center">
  <img src="assets/images/logo.jpg" alt="SPCLib - Halo, SAPP, Phasor" width="250">

  <br>

  <a href="mailto:chalwk.dev@gmail.com">
    <img src="https://img.shields.io/badge/Email-chalwk.dev@gmail.com-c14438?style=for-the-badge&logo=gmail&logoColor=white" alt="Email">
  </a>

  <a href="https://discord.gg/D76H7RVPC9">
    <img src="https://img.shields.io/badge/SPCLib_Discord-Join_Server-7289DA?style=for-the-badge&logo=discord&logoColor=white" alt="SPCLib Discord Server">
  </a>

  <a href="https://chalwk.github.io/">
    <img src="https://img.shields.io/badge/Chalwk's Website-Visit-0A66C2?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Portfolio Website">
  </a>
</div>

<br>

---

> [!IMPORTANT]
> **Educational content (guides, tutorials, reference materials) has moved to [chalwk.github.io/blog](https://chalwk.github.io/blog).**  
> This repository now contains **only Lua scripts** for SAPP/Phasor/Chimera.

---

## Table of Contents

* [1. Overview](#overview)
* [2. What are SAPP, Phasor and Chimera?](#what-are-sapp-phasor-and-chimera)
* [3. SAPP Version Archive](#sapp-archive--mirrors)
* [4. Scripts, Releases and Knowledge Base](#scripts-releases-and-knowledge-base)
* [5. Integration Tools](#integration-tools)
    * [5.1 SAPPDiscordBot](#sappdiscordbot)
* [6. Contributors, Community Guidelines & Request Features](#contributors-community-guidelines--request-features)
    * [6.1 Submit Ideas](#submit-ideas)
    * [6.2 Report Issues](#report-issues)
* [7. Halo Custom Edition Installer](#halo-custom-edition-installer)
    * [7.1 LAA Patched Executables](#laa-patched-executables)
* [8. Community Hubs](#community-hubs)
* [9. Shoutout to Clans (Past and Present)](#shoutout-to-clans-past-and-present)
* [10. Support My Work](#support-my-work)
* [11. License](#license)

---

## Overview

**SPCLib** *(SAPP, Phasor and Chimera Library)* is the largest public archive of Lua scripts and resources for the SAPP
and Phasor dedicated server extensions and the Chimera client-side mod, for Halo PC and Custom Edition. All Lua scripts
in **SPCLib** are written and curated by Chalwk, unless otherwise noted.

Here, you will find a wide range of scripts, guides, and insights to enhance, customize, and extend your multiplayer
server experience.

---

## What are SAPP, Phasor and Chimera?

**SAPP** and **Phasor** are server-side extensions for `haloded.exe`/`haloceded.exe` that provide advanced scripting and
customization capabilities for dedicated servers.

**SAPP** was developed by sehé and is the most feature-rich and widely used extension. It provides powerful Lua
scripting support, anti-cheat tools, event hooks, command handling, player management, logging, and numerous
under-the-hood features.

**Phasor** is an earlier extension with similar goals.

SAPP and Phasor are no longer actively maintained, but stable and complete in their final released versions.

**[Chimera](https://github.com/SnowyMouse/chimera)** is a client-side mod for Halo Custom Edition, PC, and Trial that
also exposes a Lua API. Developed by SnowyMouse, it is actively maintained and provides event hooks,
commands, built-in map downloads, and dozens of quality-of-life fixes. Chimera scripts are fully supported in SPCLib.

---

## SAPP Archive & Mirrors

The official SAPP website (halo.isimaginary.com) is no longer accessible. To ensure that historical versions remain
available for the community, this repository also serves as a mirror for all released SAPP binaries.

You'll find the full archive of SAPP versions, from earlier builds all the way to the final release in the
**[`./assets/sapp_downloads`](./assets/sapp_downloads)** folder. These files are unmodified and provided as-is for
archival, preservation, and server-maintenance purposes.

Additionally, this repository hosts a mirror of the official SAPP documentation PDF
files: [Revision 2.4](docs/SAPP%20Documentation%20Revision%202.4.pdf)
and [Revision 2.5](docs/SAPP%20Documentation%20Revision%202.5.pdf). These documents were written by 002 (SnowyMouse) and
are preserved here for historical reference.

The community memory offsets list ([offsets.lua](reference/offsets.lua)), originally created by Wizard, is also
preserved here as a reference.

> **License notice:** The [MIT license](LICENSE) of this repository applies to the original content (Lua scripts,
> documentation, etc.). The SAPP binaries themselves are closed-source software created by sehé, and the mirrored
> SAPP documentation PDFs were authored by 002 (SnowyMouse). Their inclusion here does not imply any change to their
> original licenses. This mirror exists purely to keep these resources accessible now that the original distribution
> channel is gone.

---

## Scripts, Releases and Knowledge Base

### Structure:

- **admin:** Strictly moderation & enforcement (bans, kicks, anti-cheat, rule enforcement)
- **chat:** Chat formatting, messages, and command handling
- **gameplay:** Gameplay mechanics, modifiers, and fun items
- **gametypes:** Custom game modes and gametype variations
- **modules:** Library modules for other scripts
- **notifications:** Console output, timers, and event alerts
- **utility:** Server configuration, spawning, map control, and miscellaneous tools

| Category                                                           | Description                                                                                                                                                                                             |
|--------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [**SAPP Scripts**](./sapp)                                         | [admin](./sapp/admin), [chat](./sapp/chat), [gameplay](sapp/gameplay), [gametypes](sapp/gametypes), [modules](sapp/modules), [notifications](sapp/notifications), [utility](sapp/utility)               |
| [**Phasor Scripts**](./phasor)                                     | [admin](./phasor/admin), [chat](./phasor/chat), [gameplay](phasor/gameplay), [gametypes](phasor/gametypes), [modules](phasor/modules), [notifications](phasor/notifications), [utility](phasor/utility) |
| [**Chimera Scripts**](./chimera)                                   | Chimera Scripts                                                                                                                                                                                         |
| [**Releases**](https://github.com/Chalwk/SPCLib/releases)          | Larger SAPP projects with advanced functionality beyond standard scripts                                                                                                                                |
| [**Knowledge Base (docs)**](https://chalwk.github.io/blog/#page-1) | Documentation and community knowledge base                                                                                                                                                              |

---

## Integration Tools

### SAPPDiscordBot

[![Java](https://img.shields.io/badge/Java-17%2B-orange.svg)](https://github.com/Chalwk/SAPPDiscordBot)
[![GitHub release](https://img.shields.io/github/v/release/Chalwk/SAPPDiscordBot)](https://github.com/Chalwk/SAPPDiscordBot/releases)

A Java application that uses the [JDA API](https://github.com/discord-jda/JDA) to connect Halo SAPP server events to
Discord, providing real-time alerts, structured embeds, and a GUI interface for monitoring your servers.

**Features:**

- Real-time event monitoring for multiple Halo servers
- Rich Discord embeds with customizable templates
- GUI interface for easy configuration
- Support for all SAPP event types (joins, deaths, scores, chat, etc.)
- Cross-platform (Windows & Linux)

**[→ Visit SAPPDiscordBot Repository](https://github.com/Chalwk/SAPPDiscordBot)**

### Script Browser

[![Script Browser](https://img.shields.io/badge/Script_Browser-Open_Now-7289DA?style=for-the-badge&logo=google-chrome&logoColor=white)](https://chalwk.github.io/SPCLib/)

A live, searchable web interface that lets you explore every script in SPCLib without touching the repository.  
Filter by platform (SAPP, Phasor, Chimera, Releases), browse by category, search by name or description, and download
`.lua` files directly - all from one page.

**[→ Open the Script Browser](https://chalwk.github.io/SPCLib/)**

---

## Contributors, Community Guidelines & Request Features

See our [Contributing Guide](https://github.com/Chalwk/SPCLib/blob/master/CONTRIBUTING.md) to learn how to
get involved.

All community interactions are governed by
our [Code of Conduct](https://github.com/Chalwk/SPCLib/blob/master/CODE_OF_CONDUCT.md)

### Submit Ideas

Have an idea for a new feature or script?  
[Submit Feature Request](https://github.com/Chalwk/SPCLib/issues/new?template=FEATURE_REQUEST.yaml)

### Report Issues

- [Bug Report Form](https://github.com/Chalwk/SPCLib/issues/new?assignees=Chalwk&labels=Bug%2CNeeds+Triage&projects=&template=BUG_REPORT.yaml&title=%5BBUG%5D+%3Ctitle%3E)
- [Feature Request Form](https://github.com/Chalwk/SPCLib/issues/new?assignees=Chalwk&labels=Feature%2CNeeds+Review&projects=&template=FEATURE_REQUEST.yaml&title=%5BFEATURE%5D+%3Ctitle%3E)

---

## Halo Custom Edition Installer:

**Note:** You need your own CD Key to install this.

[halo_ce_installer.zip](https://drive.google.com/file/d/1TTiBYhO9JS5Js0exRlygH9pAC2yV1KsV/view?usp=sharing)  
[haloce-patch-1.0.10.zip](https://drive.google.com/file/d/1CIPg3XZ3VIm4ngUnDqLCRNSn9x-jxD6W/view?usp=drive_link)

### LAA Patched Executables

These are Large Address Aware (LAA) patched versions of Halo executables, allowing the game to use more than 2 GB of RAM
on 64-bit systems:

- [Download Page](https://github.com/Chalwk/SPCLib/releases/tag/laa_patched)

---

## Community Hubs

| Hub Name            | Link(s)                                                                                                                                          | Description                                                                                                                                                                                                                                                                                                                                                                                |
|:--------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Chalwk (SPCLib)** | [Website](https://chalwk.github.io/) \| [Discord](https://discord.gg/D76H7RVPC9)                                                                 | Personal website and portfolio of Chalwk. The site serves as a playground for educational content (including Halo-related tutorials on the [blog page](https://chalwk.github.io/blog/)), as well as PWA web tools and apps. Only about 20% of the content is Halo-specific. The Discord server is a community hub for discussion, support, and collaboration on SPCLib and Halo scripting. |
| **Open Carnage**    | [Website](https://opencarnage.net) \| [Discord](https://discord.gg/2pf3Yjb)                                                                      | Open Carnage was a long-running forum and resource for Halo Custom Edition and MCC modding. The community entered a read-only state in 2023 following persistent DDoS attacks, which also resulted in the loss of a significant amount of content. It was considered one of the last major Halo CE modding forums.                                                                         |
| **Chimera**         | [Forum Thread](https://opencarnage.net/index.php?/topic/6916-chimera-download-source-code-and-discord/) \| [Discord](https://discord.gg/ZwQeBE2) | Chimera is an essential client-side mod for Halo Custom Edition, PC "Retail", and Trial. Often described as "the update to Halo PC that never was," it extends game limits, addresses renderer issues, and applies dozens of fixes and quality-of-life improvements, such as built-in map downloads.                                                                                       |
| **Halo Net**        | [Website](https://halonet.net/)                                                                                                                  | HaloNet.Net is a central hub for Halo PC modding, primarily known for hosting the massive HAC2 map repository and update servers. The repository contains thousands of custom maps totaling many gigabytes of content, which are automatically downloaded by HAC2 and Chimera when joining a server.                                                                                       |
| **XG Gaming**       | [Website](https://www.xgclan.com) (archived)                                                                                                     | **XG Gaming** (also known as **Extreme Gaming**) was a clan community for Halo PC/CE and other online games. According to archived snapshots of their now-defunct website, they provided forums, server listings, clan information, and downloads. The original domain is no longer active, but historical records can be viewed via the Wayback Machine.                                  |
| **POQ Clan**        | [Website](http://poqclan.com/)                                                                                                                   | The Players of Quality (PÕQ) Clan is one of the oldest and largest Halo PC/CE clans, established in 2006. They maintain 19 dedicated public servers, some of which feature custom modifications like extra portals, no falling damage, powered snipers, and flying warthogs. Many of their servers are rated among the most popular on Halo PC/CE.                                         |
| **BK (BlacksHalo)** | [Website](https://www.blackshalo.com)                                                                                                            | Blackshalo (BK) is a well-known clan in the Halo PC community, having run original and popular servers for both Custom Edition and Combat Evolved for over 15 years. They are recognized as one of the biggest and best-known clans in Halo, and their website provides forums for news, general topics, and server administration.                                                        |
| **Liberty**         | [Discord](https://discord.gg/3J2Zppghz5)                                                                                                         | Liberty is an active Halo Custom Edition community founded in 2024. They host servers for classic and custom maps, including CTF, Slayer, Oddball, and a dedicated Racing server. The community emphasizes fair play, custom content, and friendly social interaction, with Discord used for events, server alerts, and player coordination.                                               |
| **Reclaimers**      | [Website](https://c20.reclaimers.net/) \| [Discord](https://discord.reclaimers.net/)                                                             | The Reclaimers Library (c20) is a comprehensive, community-maintained wiki and resource hub for Halo modding. It documents the tribal knowledge of the modding community for Halo Custom Edition and the MCC mod tools for all mainline titles, serving as a repository of guides, tool documentation, and technical references.                                                           |
| **Realworld CE**    | [Website](https://www.realworldce.com/)                                                                                                          | Realworld CE is a guild and custom map blog for Halo Custom Edition. The site hosts hundreds of multiplayer custom maps (no single-player or AI maps), many of which are played on the guild’s own dedicated servers. Maps can be downloaded individually or in packs at full speed, and some maps are exclusive to this site. The blog is maintained by Harbinge® and Dwight®.            |

---

## Shoutout to Clans (Past and Present)

> \- YAS -, -db-, «§», «Ag~, «Ð²Ä», «MAD», [Aķ], [CV], [GTV], [HGE], [IG], [IS], [K2], [McK], [Nbk], [VR], [WFFF], ]
> ZTA[. VSA, {ATP}, {BK}, {CK}, {CRG}, {HWS}, {LoH}, {NR}, {OTH}, {ØZ}, {PWH}, {SK}, {SSC}, {V3}, {X}, {XF} = SL =,
> {XG}, = EP =, = NcS =, = XA=, =DN=, =RDA=, £V», ÄÄÄ, AOD, AR, BR, BZ, C#w, CAF, CB, CES, CGD, CHr, CK, ÇM, CODE, CSI,
> CST, DFS, DR, Ðu¥, EK, ev, FCM, Fem1, Fez`, FIG, FooK, GDS, GoD, GRO, HH, HSF, HTK3, IR, KB, KMT, KoD, KoF, LaG, LF,
> LIB, LNZ, LP, LTD2, M5, MR, MVL, ňc, ÑE», ñuß, OSR, OWV, P§ycho, PÕQ, PRO, RC, RSF, SAR, SB, SDR, ßE, TBR, TCS, TFT,
> TM, ToR, X¬, xOSHx, xT

---

## Support My Work

Enjoy these projects? Help me continue development:

- ☕ [Donate via PayPal](https://www.paypal.com/ncp/payment/XUPTKDU6LKM3G)
- **Star ⭐ this repository** to show appreciation and stay updated!

## License

SPCLib is licensed under the [MIT License](LICENSE).

---

Halo is a trademark of Microsoft. This project is not affiliated with or endorsed by Microsoft or its subsidiaries,
including Halo Studios (formerly 343 Industries).