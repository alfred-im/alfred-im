// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import * as fs from 'node:fs';

import type {
  FullConfig,
  Reporter,
  Suite,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

function writeNow(fd: number, chunk: string | Buffer): void {
  const text = typeof chunk === 'string' ? chunk : chunk.toString('utf8');
  fs.writeSync(fd, text.endsWith('\n') ? text : `${text}\n`);
}

/**
 * Inoltra stdout/stderr dei worker Playwright al terminale senza buffering.
 * Senza questo reporter i log `[snake]` restano in coda fino a fine test.
 */
class SnakeStdioReporter implements Reporter {
  printsToStdio(): boolean {
    return false;
  }

  onBegin(_config: FullConfig, suite: Suite): void {
    if (process.env.ALFRED_SNAKE_VERBOSE === '0') return;
    writeNow(
      1,
      `[snake] ${new Date().toISOString()} · runner begin planned=${suite.allTests().length}`,
    );
  }

  onTestBegin(test: TestCase): void {
    if (process.env.ALFRED_SNAKE_VERBOSE === '0') return;
    writeNow(
      1,
      `[snake] ${new Date().toISOString()} · playwright BEGIN ${test.title}`,
    );
  }

  onStdOut(chunk: string | Buffer): void {
    if (process.env.ALFRED_SNAKE_VERBOSE === '0') return;
    writeNow(1, chunk);
  }

  onStdErr(chunk: string | Buffer): void {
    if (process.env.ALFRED_SNAKE_VERBOSE === '0') return;
    writeNow(2, chunk);
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    if (process.env.ALFRED_SNAKE_VERBOSE === '0') return;
    writeNow(
      1,
      `[snake] ${new Date().toISOString()} · playwright END ${test.title} status=${result.status} ${result.duration}ms`,
    );
    for (const err of result.errors) {
      const message = err.message ?? String(err);
      writeNow(2, `[snake] ${new Date().toISOString()} · playwright ERROR ${message}`);
    }
  }
}

export default SnakeStdioReporter;
