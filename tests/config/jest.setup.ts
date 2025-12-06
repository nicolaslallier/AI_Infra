/**
 * Jest Setup File
 * 
 * Global setup for Jest tests - runs before each test file
 */

import { config } from 'dotenv';
import path from 'path';

// Load test environment variables
config({ path: path.join(__dirname, '.env.test') });

// Set test timeout
jest.setTimeout(30000);

// Global test utilities
global.console = {
  ...console,
  // Suppress console.log in tests unless VERBOSE is true
  log: process.env.VERBOSE === 'true' ? console.log : jest.fn(),
  debug: process.env.DEBUG === 'true' ? console.debug : jest.fn(),
  info: console.info,
  warn: console.warn,
  error: console.error,
};

// Mock Date for consistent testing
const mockDate = new Date('2024-01-01T00:00:00.000Z');
global.Date = class extends Date {
  constructor(...args: any[]) {
    if (args.length === 0) {
      super(mockDate);
    } else {
      super(...args);
    }
  }
} as any;

// Global beforeAll
beforeAll(async () => {
  console.info('🧪 Starting test suite...');
});

// Global afterAll
afterAll(async () => {
  console.info('✅ Test suite completed');
});

// Global beforeEach
beforeEach(() => {
  // Reset mocks before each test
  jest.clearAllMocks();
});

// Global afterEach
afterEach(() => {
  // Cleanup after each test
});

// Extend Jest matchers if needed
expect.extend({
  toBeWithinRange(received: number, floor: number, ceiling: number) {
    const pass = received >= floor && received <= ceiling;
    if (pass) {
      return {
        message: () => `expected ${received} not to be within range ${floor} - ${ceiling}`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be within range ${floor} - ${ceiling}`,
        pass: false,
      };
    }
  },
});

export {};

