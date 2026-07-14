// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

export 'prepare_image_for_upload_stub.dart'
    if (dart.library.html) 'prepare_image_for_upload_web.dart'
    if (dart.library.io) 'prepare_image_for_upload_io.dart';
