#!/bin/bash
set -e

# When the container runs with --user UID:GID, that UID may not exist in
# /etc/passwd.  sudo requires the invoking user to be in /etc/passwd, so we
# register a placeholder entry before handing off to make.
if ! getent passwd "$(id -u)" > /dev/null 2>&1; then
    echo "builduser:x:$(id -u):$(id -g)::/tmp:/bin/bash" >> /etc/passwd
fi

# Set up a per-run GPG home with correct permissions (700 required by gpg).
# Copies the template gpg.conf (which enables auto-key-retrieve) so that
# makepkg can fetch any required signing key on demand without hardcoding
# specific fingerprints in the image.
export GNUPGHOME=/tmp/.gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
cp /etc/makepkg-gnupg-template/gpg.conf "$GNUPGHOME/gpg.conf"

exec make "$@"
