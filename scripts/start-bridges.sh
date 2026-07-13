#!/bin/sh
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -e
python bridge-xmpp/main.py &
python bridge-matrix/main.py &
wait
