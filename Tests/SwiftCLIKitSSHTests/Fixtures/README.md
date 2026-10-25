# SSH key fixtures

Test-only keys, generated with `ssh-keygen` on 2026-10-20 and used for nothing else. They exist
so the host key loader is checked against files OpenSSH itself wrote, rather than against bytes
the tests assembled from the loader's own reading of the format.

| File | Made with |
|---|---|
| `host_ed25519`, `host_ed25519.pub` | `ssh-keygen -t ed25519 -N ""` |
| `host_ed25519_encrypted` | `ssh-keygen -t ed25519 -N "fixture-passphrase"` |
| `host_ecdsa` | `ssh-keygen -t ecdsa -b 256 -N ""` |
| `user_ed25519`, `user_ed25519.pub` | `ssh-keygen -t ed25519 -N "" -C fixture-user` (2026-10-24, OpenSSH 10.3p1) |
| `user_ca_ed25519.pub` | `ssh-keygen -t ed25519 -N "" -C fixture-ca`; the private half was deleted after signing |
| `user_ed25519-cert.pub` | `ssh-keygen -s user_ca_ed25519 -I fixture-key-id -n alice,ops -V 20260101000000Z:20360101000000Z -z 42 user_ed25519.pub` |
| `user_ed25519-cert.txt` | `TZ=UTC ssh-keygen -L -f user_ed25519-cert.pub`: the expected values for the certificate tests |

Git does not keep a file's mode, so the tests copy each fixture to a temporary file with mode
`0600` before loading it.
