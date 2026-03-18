# Server-Setup

## Description

One script to setup a new server with essential tools and configurations.

## Software Installed

| Package   | Description                          |
| --------- | ------------------------------------ |
| `ncdu`    | Disk usage analyzer                  |
| `htop`    | Interactive process viewer           |
| `git`     | Version control                      |
| `curl`    | HTTP client                          |
| `ranger`  | Terminal file manager                |
| `nano`    | Simple text editor                   |
| `micro`   | Modern terminal text editor          |
| `restic`  | Backup tool                          |
| `rsync`   | File sync / transfer                 |
| `fresh`   | Dependency manager for shell configs |
| `fish`    | Friendly interactive shell           |
| `tmux`    | Terminal multiplexer                 |
| `wget`    | File downloader                      |
| `fd`      | Fast `find` alternative (`fd-find`)  |
| `cockpit` | Web-based server management UI       |

### Optional

| Package  | Description                               |
| -------- | ----------------------------------------- |
| `docker` | Container runtime (prompted during setup) |

## Configuration

- Sets default shell to **fish** for the invoking user
- Enables **tmux mouse support** system-wide (`/etc/tmux.conf`)
- Enables and starts the **Cockpit** web interface (`cockpit.socket`)
- Creates a `fd` symlink for `fd-find` (Debian/Ubuntu compatibility)
