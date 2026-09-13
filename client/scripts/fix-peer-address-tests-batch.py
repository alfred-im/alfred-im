#!/usr/bin/env python3
"""One-shot batch fixes for peerAddress migration in client/test."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def patch_file(path: Path, replacements: list[tuple[str, str]]) -> None:
    text = path.read_text()
    original = text
    for old, new in replacements:
        text = text.replace(old, new)
    if text != original:
        path.write_text(text)


COMMON: list[tuple[str, str]] = [
    ("peerAddress: 'account-a'", "peerAddress: 'agent_a'"),
    ("peerAddress: 'account-b'", "peerAddress: 'agent_b'"),
    ("activePeer?.profileId, 'account-a'", "activePeer?.peerAddress, 'agent_a'"),
    ("activePeer?.profileId, 'account-b'", "activePeer?.peerAddress, 'agent_b'"),
    ("viewState.activePeer?.profileId, 'account-a'", "viewState.activePeer?.peerAddress, 'agent_a'"),
    ("viewState.activePeer?.profileId, 'account-b'", "viewState.activePeer?.peerAddress, 'agent_b'"),
    ("lastPeer?.profileId, 'peer-b'", "lastPeer?.peerAddress, 'peer-b'"),
    ("viewState.activePeer?.profileId, 'peer-b'", "viewState.activePeer?.peerAddress, 'peer-b'"),
    ("viewState.activePeer?.profileId, 'peer-x'", "viewState.activePeer?.peerAddress, 'peer-x'"),
    ("'peer_profile_id'", "'peer_address'"),
    ("peer_profile_id", "peer_address"),
]

for dart in ROOT.rglob("*.dart"):
    patch_file(dart, COMMON)

# push_conversation_key snake_case payload
patch_file(
    ROOT / "unit/push_conversation_key_test.dart",
    [
        (
            "'peer_profile_id': 'peer-b'",
            "'peer_address': 'peer-b'",
        ),
    ],
)

# multi-account message keys
patch_file(
    ROOT / "unit/multi_account_chat_scenario_test.dart",
    [
        ("peerAddress: _agent2", "peerAddress: 'alfredagent2'"),
        ("peerAddress: _agent1", "peerAddress: 'alfredagent1'"),
    ],
)

patch_file(
    ROOT / "unit/messages_controller_multi_account_test.dart",
    [
        ("peerAddress: _agent2", "peerAddress: 'alfredagent2'"),
        ("peerAddress: _agent1", "peerAddress: 'alfredagent1'"),
    ],
)

# shareable link wiring
patch_file(
    ROOT / "wiring/shareable_link_wiring_test.dart",
    [
        ("peerAddress: linkPeerId", "peerAddress: 'link_z'"),
        ("auth.activePeer?.profileId, linkPeerId", "auth.activePeer?.peerAddress, 'link_z'"),
    ],
)

print("batch peer-address test fixes applied")
