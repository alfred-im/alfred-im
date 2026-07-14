// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

/// Upper bound for client-side media probing (duration, player init).
const Duration mediaProbeTimeout = Duration(seconds: 6);

Future<T> withMediaProbeTimeout<T>(
  Future<T> future, {
  required FutureOr<T> Function() onTimeout,
}) =>
    future.timeout(mediaProbeTimeout, onTimeout: onTimeout);
