# SSH host key fixtures

Test-only keys, generated with `ssh-keygen` on 2026-10-20 and used for nothing else. They exist
so the host key loader is checked against files OpenSSH itself wrote, rather than against bytes
the tests assembled from the loader's own reading of the format.

| File | Made with |
|---|---|
| `host_ed25519`, `host_ed25519.pub` | `ssh-keygen -t ed25519 -N ""` |
| `host_ed25519_encrypted` | `ssh-keygen -t ed25519 -N "fixture-passphrase"` |
| `host_ecdsa` | `ssh-keygen -t ecdsa -b 256 -N ""` |

Git does not keep a file's mode, so the tests copy each fixture to a temporary file with mode
`0600` before loading it.
