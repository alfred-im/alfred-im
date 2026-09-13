#!/usr/bin/env python3
"""One-shot test migration helper for peer_address client migration."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"

RENAMES = [
    ("peerProfileId", "peerAddress"),
    ("selectedPeerId", "selectedPeerAddress"),
    ("findByProfileId", "findByPeerAddress"),
    ("activePeerProfileId", "activePeerAddress"),
    ("allowedProfileIds", "allowedAddresses"),
    ("isProfileAllowed", "isAddressAllowed"),
    ("removeByProfileId", "removeByAddress"),
    ("removeInternalByProfileId", "removeByAddress"),
    ("contactForProfileId", "contactForAddress"),
    ("sendToProfile", "sendToAddress"),
    ("sendGifToProfile", "sendGifToAddress"),
    ("sendImageToProfile", "sendImageToAddress"),
    ("sendVideoToProfile", "sendVideoToAddress"),
    ("recipientProfileId", "peerAddress"),
    ("profilesById", "profilesByAddress"),
    ("RemoveAllowedByProfileId", "RemoveAllowedByAddress"),
    ("AddInternalContact", "AddContactByAddress"),
    ("RemoveInternalContact", "RemoveContactByAddress"),
    ("AddExternalContact", "AddContactByAddress"),
    (".addInternal(", ".addByAddress("),
    (".addExternal(", ".addByAddress("),
    (".added", ".addedAddresses"),
]


def migrate_text(text: str) -> str:
    for old, new in RENAMES:
        text = text.replace(old, new)

    text = re.sub(
        r"ChatPeer\.fromProfile\(\s*profile:",
        "ChatPeer.fromProfile(peerAddress: profile.resolvedPeerAddress, profile:",
        text,
    )
    text = re.sub(
        r"ChatPeer\(\s*profile:",
        "ChatPeer(peerAddress: 'peer-test', profile:",
        text,
    )

    def add_address(match: re.Match[str]) -> str:
        block = match.group(0)
        if "address:" in block:
            return block
        um = re.search(r"username:\s*'([^']*)'", block)
        if um and um.group(1):
            token = f"username: '{um.group(1)}'"
            return block.replace(token, f"{token}, address: '{um.group(1)}'", 1)
        return block

    text = re.sub(r"ProfileSummary\([^)]{0,300}\)", add_address, text)

    text = re.sub(r"linkedProfileId:\s*[^,\n]+,\s*", "", text)
    text = re.sub(r"externalAddress:\s*[^,\n]+,\s*", "", text)
    text = re.sub(
        r"Contact\(\s*([^)]*?)displayName:\s*[^,\n]+,\s*",
        r"Contact(\1",
        text,
    )
    text = re.sub(
        r"Contact\(\s*([^)]*?)avatarUrl:\s*[^,\n]+,\s*",
        r"Contact(\1",
        text,
    )

    text = re.sub(
        r"AllowedPerson\(\s*entryId:\s*'([^']+)',\s*profile:\s*([a-zA-Z_][a-zA-Z0-9_]*)",
        r"AllowedPerson(entryId: '\1', allowedAddress: \2.resolvedPeerAddress, profile: \2",
        text,
    )

    return text


def main() -> None:
    for path in sorted(ROOT.rglob("*.dart")):
        original = path.read_text()
        updated = migrate_text(original)
        if updated != original:
            path.write_text(updated)


if __name__ == "__main__":
    main()
