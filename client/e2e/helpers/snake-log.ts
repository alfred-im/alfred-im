// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/** Log strutturato per individuare il passo core nel serpente release. */
export function snakeStep(stepId: string, detail?: string): void {
  const suffix = detail ? ` ${detail}` : '';
  console.log(`[snake] >>> step=${stepId}${suffix}`);
}
