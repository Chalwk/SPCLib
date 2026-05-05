[![Discord](https://img.shields.io/badge/Discord-Join_Our_Server-7289DA?style=for-the-badge&logo=discord)](https://discord.gg/D76H7RVPC9)

# Contributing to the SPCLib

Thank you for considering contributing to **SPCLib**! Your contributions help maintain, improve,
and expand the collection of SAPP/Phasor Lua scripts and resources for **Halo: CE** and **Halo: PC** dedicated servers.
Following these guidelines ensures a smooth and collaborative process.

---

## How to Contribute

### Issues and Suggestions

* **Check First**: Before creating a new issue, search
  the [Issues Section](https://github.com/Chalwk/SPCLib/issues) to see if your concern, bug, or feature
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

If you've created a brand‑new Lua script for SAPP or Phasor and would like it to be included in the
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
your script will be licensed under the same terms as the rest of the repository (see [LICENSE](LICENSE)).

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

For a detailed guide on Markdown formatting, refer to [markdown guide](https://www.markdownguide.org/).

---

## Communication

### Collaboration Etiquette

* **Be Respectful**: Communicate kindly with contributors and SPCLib maintainers.
* **Respond Promptly**: Address comments or questions on your PRs in a timely manner.
* **Open to Feedback**: Accept constructive feedback and make improvements as needed.

---

## Contributors

I'd like to recognize these amazing people:

| **User**                                                            | **Description**                                                                                                                                                                                                                                            | **Source**                                                                                                                                                                                                                                                                                                                                                                 |
|---------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [urbanyoung](https://github.com/urbanyoung)                         | Author of the Halo server extension **Phasor**.                                                                                                                                                                                                            | [Phasor Repository](https://github.com/urbanyoung/Phasor)                                                                                                                                                                                                                                                                                                                  |
| [sehé°°](http://halo.isimaginary.com/forum/user-1.html)             | 1. Author of the Halo server extension **SAPP**.<br>2. Created the **death message patch** (*integrated into some Phasor scripts*).                                                                                                                        | [User Profile](http://halo.isimaginary.com/forum/user-1.html)                                                                                                                                                                                                                                                                                                              |
| [AelitePrime](http://phasor.proboards.com/user/37)                  | Created the **commands script** for Phasor.                                                                                                                                                                                                                | [Commands Script](http://pastebin.com/gHiz0A51)                                                                                                                                                                                                                                                                                                                            |
| [Benjamin Auquite (Wizard)](https://github.com/th3w1zard1)          | Created the addresses & offsets list.                                                                                                                                                                                                                      | [Offsets List](./misc/offsets.lua)                                                                                                                                                                                                                                                                                                                                         |
| [Nuggets](http://phasor.proboards.com/user/36)                      | Created the **Console Text Overload** utility (*integrated into some of Phasor scripts*).                                                                                                                                                                  | [Console Text Overload](http://pastebin.com/1dtn0DiM)                                                                                                                                                                                                                                                                                                                      |
| [002 (Kavawuvi\SnowyMouse)](https://github.com/SnowyMouse)          | 1. Creator of **Chimera (OC)**.<br>2. Created the **SAPP HTTP Client** (*integrated into some SAPP scripts*).<br>3. Created the **get_tag_info()** function (*integrated into some SAPP scripts*).<br>4. Created the **Comprehensive SAPP Documentation**. | 1. [Chimera (OC)](https://opencarnage.net/index.php?/forum/78-chimera-general/) / [Chimera (GitHub)](https://github.com/SnowyMouse/chimera)<br>2. [HTTP Client](https://opencarnage.net/index.php?/topic/5998-sapp-http-client/#comment-82077)<br>3. [SAPP Documentation](https://opencarnage.net/index.php?/topic/3806-comprehensive-sapp-documentation-rev-25-sapp-101/) |
| [giraffe](https://opencarnage.net/index.php?/profile/1463-giraffe/) | Created the **Auto Vehicle Flip** SAPP script (*integrated into some SAPP scripts*).                                                                                                                                                                       | [Auto Vehicle Flip](https://opencarnage.net/index.php?/topic/6251-auto-vehicle-flip/)                                                                                                                                                                                                                                                                                      |
| [Jeffrey Friedl](http://regex.info/blog/)                           | Creator of the **JSON Interpreter** (Library) for Lua.                                                                                                                                                                                                     | [JSON Interpreter](http://regex.info/blog/lua/json)                                                                                                                                                                                                                                                                                                                        |
| [edgardanielgd](https://github.com/edgardanielgd)                   | Contributed code to the [Admin Manager](https://github.com/Chalwk/SPCLib/releases/tag/AdminManager).                                                                                                                                                       |                                                                                                                                                                                                                                                                                                                                                                            |

---

## License

By contributing to SPCLib, you agree that your contributions will be licensed under the same terms as the repository.<br>
For details, see the [LICENSE](LICENSE) file.

---

## Why Your Contributions Matter

* **Keep Scripts Updated**: Help ensure scripts remain functional and compatible with SAPP or Phasor.
* **Support the Community**: Assist server admins and operators with better tools and resources.
* **Enhance Gameplay**: Every improvement or new feature enriches the Halo multiplayer experience.