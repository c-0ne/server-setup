# Server-Setup

## Description

One script to setup a new server with essential tools and configurations.

## Software Installed

| Package   | Description                                                                                                    |
| --------- | -------------------------------------------------------------------------------------------------------------- |
| `ncdu`    | Disk usage analyzer                                                                                            |
| `htop`    | Interactive process viewer                                                                                     |
| `git`     | Version control                                                                                                |
| `curl`    | HTTP client                                                                                                    |
| `ranger`  | Terminal file manager                                                                                          |
| `nano`    | Simple text editor                                                                                             |
| `micro`   | Modern terminal text editor                                                                                    |
| `restic`  | Backup tool                                                                                                    |
| `rsync`   | File sync / transfer                                                                                           |
| `fresh`   | Dependency manager for shell configs                                                                           |
| `superfile` | Terminal file manager                                                                                        |
| `fish`    | Friendly interactive shell                                                                                     |
| `tmux`    | Terminal multiplexer                                                                                           |
| `wget`    | File downloader                                                                                                |
| `fd`      | Fast `find` alternative (`fd-find`)                                                                            |
| `zoxide`  | Smarter directory navigation via `z`                                                                           |
| `cockpit` | Web-based server management UI. Includes `pcp`, `networkmanager`, and `packagekit` for extended functionality. |

### Optional

| Package  | Description                               |
| -------- | ----------------------------------------- |
| `docker` | Container runtime (prompted during setup) |

## Configuration

- **System Maintenance**: Performs a full system update and upgrade (`apt-get update && apt-get upgrade`).
- **Default Shell**: Sets the default shell to **fish** for the user who invoked the script with `sudo`.
- **Docker**: Adds the invoking user to the `docker` group for permission to run Docker commands without `sudo`.
- **Tmux**: Enables mouse support system-wide by adding `set -g mouse on` to `/etc/tmux.conf`.
- **Cockpit**: Enables and starts the `cockpit.socket` service so the web interface is available after boot.
- **FD Symlink**: Creates a `fd` symlink for `fd-find` for compatibility with tools expecting `fd` (common on Debian/Ubuntu).
- **Zoxide**: Configures Fish with the `z` command while leaving `cd` unchanged.
- **Cleanup**: Removes unnecessary packages and cleans the local repository of retrieved package files.
