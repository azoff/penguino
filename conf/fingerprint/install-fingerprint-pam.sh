#!/bin/sh
# Fingerprint policy: prompt at the LOCK SCREEN and for SUDO, never at initial
# login (so the login password always unlocks the gnome keyring).
# Idempotent; run as root. Originals backed up as *.bak-fprintd once.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"

install -m755 "$here/pam-user-has-session" /usr/local/sbin/pam-user-has-session

for f in common-auth sudo cosmic-greeter; do
    [ -f "/etc/pam.d/$f.bak-fprintd" ] || cp "/etc/pam.d/$f" "/etc/pam.d/$f.bak-fprintd"
done

# 1) out of the shared stack (was hit by every PAM service, incl. login)
sed -i '/pam_fprintd\.so/d' /etc/pam.d/common-auth

# 2) sudo: accept a fingerprint touch, fall through to password
if ! grep -q pam_fprintd /etc/pam.d/sudo; then
    sed -i 's|^@include common-auth|auth\tsufficient\tpam_fprintd.so max-tries=1 timeout=15\n@include common-auth|' /etc/pam.d/sudo
fi

# 3) greeter: fingerprint only when $PAM_USER already has a session (= unlock).
#    pam_exec failure (no session -> initial login) skips the fprintd line.
if ! grep -q pam_fprintd /etc/pam.d/cosmic-greeter; then
    sed -i 's|^@include common-auth|auth\t[success=ignore default=1]\tpam_exec.so quiet /usr/local/sbin/pam-user-has-session\nauth\tsufficient\tpam_fprintd.so max-tries=3 timeout=30\n@include common-auth|' /etc/pam.d/cosmic-greeter
fi

echo "fingerprint PAM policy installed: lock screen + sudo only"
