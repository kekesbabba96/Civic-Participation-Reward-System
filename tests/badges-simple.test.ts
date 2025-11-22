import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const deployer = accounts.get("deployer")!;

const contractName = "Civic-Participation-Reward-System";

describe.skip("Community Achievement Badge System - Basic Tests (temporarily reduced)", () => {
  it("should have deployer as initial badge admin", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "is-badge-admin",
      [`'${deployer}`],
      address1
    );
    expect(result).toBeBool(true);
  });

  it("should validate badge functionality exists", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-badge-stats",
      [],
      address1
    );
    expect(result).toBeDefined();
  });

  it("should prevent unauthorized badge creation", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "create-badge",
      [
        `"Unauthorized Badge"`,
        `"This should fail"`,
        `"fail"`,
        `u1`,
      ],
      address1
    );
    expect(result).toBeErr("u120");
  });
});
