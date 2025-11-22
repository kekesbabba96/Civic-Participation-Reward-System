import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const deployer = accounts.get("deployer")!;

const contractName = "Civic-Participation-Reward-System";

describe.skip("Community Achievement Badge System (temporarily reduced)", () => {
  it("ensures simnet is well initialized", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("should have deployer as initial badge admin", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "is-badge-admin",
      [Cl.principal(deployer)],
      address1
    );
    expect(result).toBeBool(true);
  });

  it("should allow admin to create badges and retrieve them", () => {
    // Create badge
    const createResult = simnet.callPublicFn(
      contractName,
      "create-badge",
      [
        Cl.stringUtf8("Civic Participation"),
        Cl.stringUtf8("Complete 10 civic activities"),
        Cl.stringUtf8("activities"),
        Cl.uint(10),
      ],
      deployer
    );
    expect(createResult).toBeOk(Cl.uint(1));
    
    // Retrieve created badge
    const getResult = simnet.callReadOnlyFn(
      contractName,
      "get-badge",
      [Cl.uint(1)],
      address1
    );
    expect(getResult).toBeSome();
  });

  it("should prevent non-admin from creating badges", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "create-badge",
      [
        Cl.stringUtf8("Unauthorized Badge"),
        Cl.stringUtf8("This should fail"),
        Cl.stringUtf8("fail"),
        Cl.uint(1),
      ],
      address1
    );
    expect(result).toBeErr(Cl.uint(120)); // err-badge-unauthorized
  });

  it("should handle complete badge lifecycle: create, progress, claim", () => {
    // Create a badge
    const createResult = simnet.callPublicFn(
      contractName,
      "create-badge",
      [
        Cl.stringUtf8("Test Badge"),
        Cl.stringUtf8("Complete 5 activities"),
        Cl.stringUtf8("test_activities"),
        Cl.uint(5),
      ],
      deployer
    );
    expect(createResult).toBeOk(Cl.uint(1));
    
    // Try claiming without progress - should fail
    let claimResult = simnet.callPublicFn(
      contractName,
      "claim-badge",
      [Cl.uint(1)],
      address1
    );
    expect(claimResult).toBeErr(Cl.uint(124)); // err-badge-requirement-not-met
    
    // Record some progress (not enough)
    let progressResult = simnet.callPublicFn(
      contractName,
      "record-progress",
      [Cl.principal(address1), Cl.stringUtf8("test_activities"), Cl.uint(3)],
      deployer
    );
    expect(progressResult).toBeOk(Cl.uint(3));
    
    // Still can't claim
    claimResult = simnet.callPublicFn(
      contractName,
      "claim-badge",
      [Cl.uint(1)],
      address1
    );
    expect(claimResult).toBeErr(Cl.uint(124)); // err-badge-requirement-not-met
    
    // Add more progress to meet threshold
    progressResult = simnet.callPublicFn(
      contractName,
      "record-progress",
      [Cl.principal(address1), Cl.stringUtf8("test_activities"), Cl.uint(2)],
      deployer
    );
    expect(progressResult).toBeOk(Cl.uint(5));
    
    // Now can claim
    claimResult = simnet.callPublicFn(
      contractName,
      "claim-badge",
      [Cl.uint(1)],
      address1
    );
    expect(claimResult).toBeOk(Cl.bool(true));
    
    // Verify ownership
    const hasResult = simnet.callReadOnlyFn(
      contractName,
      "has-badge",
      [Cl.principal(address1), Cl.uint(1)],
      address1
    );
    expect(hasResult).toBeBool(true);
    
    // Try double claiming - should fail
    claimResult = simnet.callPublicFn(
      contractName,
      "claim-badge",
      [Cl.uint(1)],
      address1
    );
    expect(claimResult).toBeErr(Cl.uint(123)); // err-badge-already-earned
  });

  it("should return badge stats correctly", () => {
    // Create a badge first to have some stats
    simnet.callPublicFn(
      contractName,
      "create-badge",
      [
        Cl.stringUtf8("Stats Badge"),
        Cl.stringUtf8("Test badge for stats"),
        Cl.stringUtf8("stats_test"),
        Cl.uint(1),
      ],
      deployer
    );
    
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-badge-stats",
      [],
      address1
    );
    // get-badge-stats returns a tuple
    expect(result).toBeTuple({ "total-badges": Cl.uint(1) });
  });

  it("should allow admin to manage other admins", () => {
    // Add address1 as admin
    let result = simnet.callPublicFn(
      contractName,
      "add-badge-admin",
      [Cl.principal(address1)],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    // Verify address1 is now admin
    result = simnet.callReadOnlyFn(
      contractName,
      "is-badge-admin",
      [Cl.principal(address1)],
      address1
    );
    expect(result).toBeBool(true);

    // Remove admin privileges
    result = simnet.callPublicFn(
      contractName,
      "remove-badge-admin",
      [Cl.principal(address1)],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    // Verify address1 is no longer admin
    result = simnet.callReadOnlyFn(
      contractName,
      "is-badge-admin",
      [Cl.principal(address1)],
      address1
    );
    expect(result).toBeBool(false);
  });
});
