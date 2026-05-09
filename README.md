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
> Educational content (guides, tutorials, reference materials) has moved
> to [chalwk.github.io/blog](https://chalwk.github.io/blog).  
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

> [!TIP]
> This project is a combined library of server-side and client-side Halo scripting resources, designed for learning,
> server management, and gameplay customization.

**SPCLib** *(SAPP, Phasor and Chimera Library)* is the largest public archive of Lua scripts and resources for the SAPP
and Phasor dedicated server extensions and the Chimera client-side mod for Halo PC and Custom Edition. All Lua scripts
in SPCLib are written and curated by Chalwk, unless otherwise noted.

Here, you will find a wide range of scripts, guides, and insights to enhance, customize, and extend your multiplayer
server experience.

---

## What are SAPP, Phasor and Chimera?

> [!NOTE]
> These tools operate at different levels of the Halo ecosystem: server-side (SAPP/Phasor) and client-side (Chimera).

**SAPP** and **Phasor** are server-side extensions for `haloded.exe`/`haloceded.exe` that provide advanced scripting and
customization capabilities for dedicated servers.

**SAPP** was developed by sehé and is the most feature-rich and widely used extension. It provides powerful Lua
scripting support, anti-cheat tools, event hooks, command handling, player management, logging, and numerous
under-the-hood features.

**Phasor** is an earlier extension with similar goals.

SAPP and Phasor are no longer actively maintained, but stable and complete in their final released versions.

**[Chimera](https://github.com/SnowyMouse/chimera)** is a client-side mod for Halo Custom Edition, PC, and Trial that
also exposes a Lua API. Developed by SnowyMouse, it is actively maintained and provides event hooks, commands, built-in
map downloads, and dozens of quality-of-life fixes. Chimera scripts are fully supported in SPCLib.

---

## SAPP Archive & Mirrors

> [!WARNING]
> SAPP is no longer officially maintained. These binaries are provided strictly for archival, preservation, and server
> maintenance purposes.

The official SAPP website (halo.isimaginary.com) is no longer accessible. To ensure historical versions remain
available, this repository mirrors all released SAPP binaries.

You'll find the full archive of SAPP versions in the **[`./assets/sapp_downloads`](./assets/sapp_downloads)** folder.

This repository also preserves:

- SAPP Documentation Revision 2.4 and 2.5 (by 002 / SnowyMouse)
- Memory offsets reference list originally created by Wizard

> [!CAUTION]
> These documents and binaries are redistributed for preservation only. Licensing remains with their original authors.

---

## Scripts, Releases and Knowledge Base

> [!TIP]
> Start with the category that matches your setup: SAPP or Phasor for server-side scripting, or Chimera for client-side
> scripting.

### Structure:

- **admin:** Strictly moderation & enforcement (bans, kicks, anti-cheat, rule enforcement)
- **chat:** Chat formatting, messages, and command handling
- **gameplay:** Gameplay mechanics, modifiers, and fun items
- **gametypes:** Custom game modes and gametype variations
- **modules:** Library modules for other scripts
- **notifications:** Console output, timers, and event alerts
- **utility:** Server configuration, spawning, map control, and miscellaneous tools

| Category                                                           | Description                                                       |
|--------------------------------------------------------------------|-------------------------------------------------------------------|
| [**SAPP Scripts**](./sapp)                                         | admin, chat, gameplay, gametypes, modules, notifications, utility |
| [**Phasor Scripts**](./phasor)                                     | admin, chat, gameplay, gametypes, modules, notifications, utility |
| [**Chimera Scripts**](./chimera)                                   | Client-side Chimera Lua scripts                                   |
| [**Releases**](https://github.com/Chalwk/SPCLib/releases)          | Larger advanced projects                                          |
| [**Knowledge Base (docs)**](https://chalwk.github.io/blog/#page-1) | Documentation and guides                                          |

---

## Integration Tools

> [!NOTE]
> These tools extend Halo server functionality by connecting it with external platforms like Discord and web interfaces.

### SAPPDiscordBot

[![Java](https://img.shields.io/badge/Java-17%2B-orange.svg)](https://github.com/Chalwk/SAPPDiscordBot)
[![GitHub release](https://img.shields.io/github/v/release/Chalwk/SAPPDiscordBot)](https://github.com/Chalwk/SAPPDiscordBot/releases)

A Java application using the JDA API to connect Halo SAPP server events to Discord.

Features:

- Real-time event monitoring
- Rich Discord embeds
- GUI configuration tool
- Multi-server support
- Cross-platform (Windows & Linux)

**[→ Visit SAPPDiscordBot Repository](https://github.com/Chalwk/SAPPDiscordBot)**

### Script Browser

[![Script Browser](https://img.shields.io/badge/Script_Browser-Open_Now-7289DA?style=for-the-badge&logo=google-chrome&logoColor=white)](https://chalwk.github.io/SPCLib/)

A live searchable interface for all scripts in SPCLib.

**[→ Open Script Browser](https://chalwk.github.io/SPCLib/)**

---

## Contributors, Community Guidelines & Request Features

> [!TIP]
> Contributions, bug reports, and feature requests are welcome via GitHub issues and discussion templates.

See the [Contributing Guide](CONTRIBUTING.md)

All community interaction is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md)

### Submit Ideas

[Submit Feature Request](https://github.com/Chalwk/SPCLib/issues/new?template=FEATURE_REQUEST.yaml)

### Report Issues

- [Bug Report](https://github.com/Chalwk/SPCLib/issues/new?assignees=Chalwk&labels=Bug%2CNeeds+Triage&template=BUG_REPORT.yaml)
- [Feature Request](https://github.com/Chalwk/SPCLib/issues/new?assignees=Chalwk&labels=Feature%2CNeeds+Review&template=FEATURE_REQUEST.yaml)

---

## Halo Custom Edition Installer

> [!WARNING]
> You must own a valid CD key to install Halo Custom Edition.

[halo_ce_installer.zip](https://drive.google.com/file/d/1TTiBYhO9JS5Js0exRlygH9pAC2yV1KsV/view?usp=sharing)  
[haloce-patch-1.0.10.zip](https://drive.google.com/file/d/1CIPg3XZ3VIm4ngUnDqLCRNSn9x-jxD6W/view?usp=drive_link)

### LAA Patched Executables

> [!NOTE]
> Large Address Aware (LAA) patches allow Halo to use more than 2 GB of RAM on 64-bit systems.

[Download Page](https://github.com/Chalwk/SPCLib/releases/tag/laa_patched)

---

## Community Hubs

> [!NOTE]
> Community activity varies across hubs. Some are active, others are legacy archives.

| Hub                                                                                                                                                    | Description                                                                                 |
|--------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| **Chalwk** - [Website](https://chalwk.github.io/) · [Discord](https://discord.gg/D76H7RVPC9)                                                           | Personal site & portfolio.                                                                  |
| **Open Carnage** - [Website](https://opencarnage.net) · [Discord](https://discord.gg/2pf3Yjb)                                                          | Former major CE modding forum (now read‑only after DDoS attacks).                           |
| **Chimera** - [Forum](https://opencarnage.net/index.php?/topic/6916-chimera-download-source-code-and-discord/) · [Discord](https://discord.gg/ZwQeBE2) | Essential client‑side mod with map downloads, renderer fixes, quality‑of‑life improvements. |
| **Halo Net** - [Website](https://halonet.net/)                                                                                                         | HAC2 map repository & update server - auto‑downloads thousands of custom maps.              |
| **XG Gaming** - [Website](https://www.xgclan.com) (archived)                                                                                           | Former clan community (servers, forums, downloads); domain now offline.                     |
| **POQ Clan** - [Website](http://poqclan.com/)                                                                                                          | One of the oldest Halo PC/CE clans (2006) with 19 public servers & custom mods.             |
| **BK (BlacksHalo)** - [Website](https://www.blackshalo.com)                                                                                            | Well‑known clan running popular servers for 15+ years.                                      |
| **Liberty** - [Discord](https://discord.gg/3J2Zppghz5)                                                                                                 | Active CE community (founded 2024) hosting CTF, Slayer, Oddball, Racing servers.            |
| **Reclaimers** - [Website](https://c20.reclaimers.net/) · [Discord](https://discord.reclaimers.net/)                                                   | Community wiki & resource hub for Halo CE and MCC modding tools.                            |
| **Realworld CE** - [Website](https://www.realworldce.com/)                                                                                             | Guild & custom map blog offering hundreds of exclusive multiplayer maps.                    |

---

## Shoutout to Clans (Past and Present)

> [!NOTE]
> This list represents historical and current Halo PC/CE clans and communities over many years of multiplayer history.

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

---

## License

> [!CAUTION]
> Halo is a trademark of Microsoft. This project is not affiliated with or endorsed by Microsoft or its subsidiaries,
> including Halo Studios (formerly 343 Industries).

SPCLib is licensed under the MIT License.