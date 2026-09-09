import { defineConfig } from '@playwright/test';

const snakeVerbose = process.env.ALFRED_SNAKE_VERBOSE !== '0';

export default defineConfig({
  testDir: 'e2e',
  timeout: 90_000,
  reporter: snakeVerbose
    ? [
        ['./e2e/reporters/snake-stdio-reporter.ts'],
        ['line'],
      ]
    : [['list']],
  use: {
    headless: true,
    viewport: { width: 1280, height: 720 },
  },
});
