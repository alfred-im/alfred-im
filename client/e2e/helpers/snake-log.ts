// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

function snakeTimestamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

/** Log strutturato per individuare il passo core nel serpente release. */
export function snakeStep(stepId: string, detail?: string): void {
  const suffix = detail ? ` ${detail}` : '';
  console.log(`[snake] ${snakeTimestamp()} >>> step=${stepId}${suffix}`);
}
