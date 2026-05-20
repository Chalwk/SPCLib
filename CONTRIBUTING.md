[![Discord](https://img.shields.io/badge/Discord-Join_Our_Server-7289DA?style=for-the-badge&logo=discord)][discord_invite]

# Contributing to the SPCLib

Thank you for considering contributing to **SPCLib**! Your contributions help maintain, improve,
and expand the collection of Lua scripts and resources for **Halo: PC** and **Halo: CE** dedicated servers.
Following these guidelines ensures a smooth and collaborative process.

---

## How to Contribute

### Issues and Suggestions

* **Check First**: Before creating a new issue, search
  the [Issues Section][issues_section] to see if your concern, bug, or feature
  request has already been reported.
* **Create an Issue**: If it's new, create an issue with a **clear title** and **detailed description**. Include server
  type (SAPP or Phasor) and any relevant context.

### Pull Requests

1. **Fork the Repository**: Create your own copy of the SPCLib repository.
2. **Create a Branch**: Make your changes in a new branch with a descriptive name (e.g., `fix-teleport-bug` or
   `add-gun-game-mode`).
3. **Submit a PR**: When your changes are ready, submit a pull request with a clear explanation of your additions,
   changes, or bug fixes.
4. **Follow Style Guidelines**: Ensure your Lua code follows existing SPCLib conventions, and maintain clear comments
   and formatting.

### Adding a New Script (Community Contributions)

If you've created a brand-new Lua script for SAPP or Phasor and would like it to be included in the
repository, please follow these additional steps:

* **Place your script** inside the `./community_contributions` folder at the root of the repository. This directory is
  reserved for scripts **not authored by Chalwk**.
* **Name the file** descriptively, using lowercase letters and underscores (e.g., `my_custom_gamemode.lua`). Avoid
  spaces, special characters, or version numbers in the filename.
* **Include a header comment** at the very top of your script, containing:
    - Your name or GitHub username
    - A short description of what the script does
    - The target server (SAPP, Phasor)
    - Any dependencies or specific version requirements (e.g., "requires SAPP 10.2+", "uses `map_coordinates.lua`")
* **Test thoroughly** on a local or private server to ensure the script works as intended and does not produce errors.
* **Follow the [Lua Script Guidelines](#lua-script-guidelines)** for code style, readability, and comments.
* **Submit a pull request** as described above. Chalwk will review your submission and may request changes
  before merging.

Scripts that do not adhere to these guidelines may be asked for revision or rejected. By contributing, you agree that
your script will be licensed under the same terms as the rest of the repository (see [LICENSE][license]).

---

## Code Formatting and Conventions

### Lua Script Guidelines

* Keep code **readable and well-commented**.
* Follow the **existing style** of SPCLib scripts.
* Test scripts locally to ensure they function as intended before submitting.

### Markdown / Documentation

* Use **proper Markdown formatting** for any docs or guides.
* Keep content **clear, concise, and structured**.
* Reference related scripts, server setups, or wiki pages when appropriate.

For a detailed guide on Markdown formatting, refer to [markdown guide][markdown_guide].

---

## Communication

### Collaboration Etiquette

* **Be Respectful**: Communicate kindly with contributors and SPCLib maintainers.
* **Respond Promptly**: Address comments or questions on your PRs in a timely manner.
* **Open to Feedback**: Accept constructive feedback and make improvements as needed.

---

## Contributors

I'd like to recognize these amazing people:

| **User**                                | **Description**                                                                                                                                                                                                                                | **Source**                                                                                                                                |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| [urbanyoung][urbanyoung]                | Author of Halo server extension **Phasor**.                                                                                                                                                                                                    | [Phasor Repository][phasor_repo]                                                                                                          |
| [sehé°°][sehe]                          | 1. Author of Halo server extension **SAPP**.<br>2. Created **death message patch** (*integrated into some Phasor scripts*).                                                                                                                    | [User Profile][sehe_profile]                                                                                                              |
| [AelitePrime][aeliteprime]              | Created **commands script** for Phasor.                                                                                                                                                                                                        | [Commands Script][commands_script]                                                                                                        |
| [Benjamin Auquite (Wizard)][wizard]     | Created addresses & offsets list.                                                                                                                                                                                                              | [Offsets List][offsets_list]                                                                                                              |
| [Nuggets][nuggets]                      | Created original **sendconsole_text_override**.                                                                                                                                                                                                | [sendconsole_text_override][sendconsole_override]                                                                                         |
| [002 (Kavawuvi\SnowyMouse)][snowymouse] | 1. Creator of **Chimera (OC)**.<br>2. Created **SAPP HTTP Client** (*integrated into some SAPP scripts*).<br>3. Created **get_tag_info()** function (*integrated into some SAPP scripts*).<br>4. Created **Comprehensive SAPP Documentation**. | 1. [Chimera (OC)][chimera_oc] / [Chimera (GitHub)][chimera_github]<br>2. [HTTP Client][http_client]<br>3. [SAPP Documentation][sapp_docs] |
| [giraffe][giraffe]                      | Created **Auto Vehicle Flip** SAPP script (*integrated into some SAPP scripts*).                                                                                                                                                               | [Auto Vehicle Flip][auto_vehicle_flip]                                                                                                    |
| [Jeffrey Friedl][jeffrey_friedl]        | Creator of **JSON Interpreter** (Library) for Lua.                                                                                                                                                                                             | [JSON Interpreter][json_interpreter]                                                                                                      |
| [edgardanielgd][edgardanielgd]          | Contributed code to [Admin Manager][admin_manager].                                                                                                                                                                                            |                                                                                                                                           |

---

## License

By contributing to SPCLib, you agree that your contributions will be licensed under the same terms as the
repository. For details, see the [LICENSE][license] file.

---

## Why Your Contributions Matter

* **Keep Scripts Updated**: Help ensure scripts remain functional and compatible with SAPP or Phasor.
* **Support the Community**: Assist server admins and operators with better tools and resources.
* **Enhance Gameplay**: Every improvement or new feature enriches the Halo multiplayer experience.

---

[aeliteprime]: http://phasor.proboards.com/user/37

[admin_manager]: https://github.com/Chalwk/SPCLib/releases/tag/AdminManager

[auto_vehicle_flip]: https://opencarnage.net/index.php?/topic/6251-auto-vehicle-flip/

[chimera_github]: https://github.com/SnowyMouse/chimera

[chimera_oc]: https://opencarnage.net/index.php?/forum/78-chimera-general/

[commands_script]: http://pastebin.com/gHiz0A51

[discord_invite]: https://discord.gg/D76H7RVPC9

[edgardanielgd]: https://github.com/edgardanielgd

[giraffe]: https://opencarnage.net/index.php?/profile/1463-giraffe/

[http_client]: https://opencarnage.net/index.php?/topic/5998-sapp-http-client/#comment-82077

[issues_section]: https://github.com/Chalwk/SPCLib/issues

[jeffrey_friedl]: http://regex.info/blog/

[json_interpreter]: http://regex.info/blog/lua/json

[license]: LICENSE

[markdown_guide]: https://www.markdownguide.org/

[nuggets]: http://phasor.proboards.com/user/36

[offsets_list]: reference/offsets.lua

[phasor_repo]: https://github.com/urbanyoung/Phasor

[sapp_docs]: https://opencarnage.net/index.php?/topic/3806-comprehensive-sapp-documentation-rev-25-sapp-101/

[sehe]: http://halo.isimaginary.com/forum/user-1.html

[sehe_profile]: http://halo.isimaginary.com/forum/user-1.html

[sendconsole_override]: http://pastebin.com/1dtn0DiM

[snowymouse]: https://github.com/SnowyMouse

[urbanyoung]: https://github.com/urbanyoung

[wizard]: https://github.com/th3w1zard1