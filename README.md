There are some blockers. So it doesn't work for now.

- `Jitsi` needs `openjdk-11-jre` but `Debian 12 Bookworm` provides
  `openjdk-17-jre`.

- Jitsi Team's version of [pjproject](https://github.com/jitsi/pjproject) is not
  buildable on `Debian 12 Bookworm`. Both `jibri-2.10-dev1` and
  `jibri-2.11-dev1` branches are tested but no success...

- There is an issue while creating an ephemeral LXC container by using
  `lxc-copy -e`. The ephemeral container doesn't start after copying.
