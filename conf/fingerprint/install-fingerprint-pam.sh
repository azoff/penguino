#!/bin/sh
# Fingerprint policy: prompt at the LOCK SCREEN and for SUDO, never at initial
# login (so the login password always unlocks the keyring).
# Plasma's lock screen does its own fingerprint auth; SDDM's login goes
# through common-auth, which this keeps fingerprint-free.
# Idempotent; run as root. Originals backed up as *.bak-fprintd once.
set -eu

for f in common-auth sudo; do
    [ -f "/etc/pam.d/$f.bak-fprintd" ] || cp "/etc/pam.d/$f" "/etc/pam.d/$f.bak-fprintd"
done

# 1) out of the shared stack (was hit by every PAM service, incl. login)
sed -i '/pam_fprintd\.so/d' /etc/pam.d/common-auth

# 2) sudo: accept a fingerprint touch, fall through to password
if ! grep -q pam_fprintd /etc/pam.d/sudo; then
    sed -i 's|^@include common-auth|auth\tsufficient\tpam_fprintd.so max-tries=1 timeout=15\n@include common-auth|' /etc/pam.d/sudo
fi

echo "fingerprint PAM policy installed: sudo only via PAM; lock screen is Plasma's own"
