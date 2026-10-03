import { describe, it, expect } from "vitest";

// Phase 1 smoke test: proves the admin test runner and TypeScript ESM
// resolution work in CI before real logic tests (checkout-token mint/verify,
// coupon math, webhook signature parsing) land in Phases 3 and 8.
describe("admin test harness", () => {
  it("runs", () => {
    expect(1 + 1).toBe(2);
  });
});
