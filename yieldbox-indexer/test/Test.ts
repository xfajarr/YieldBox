import assert from "assert";
import { 
  TestHelpers,
  MockPriceOracle_OwnershipTransferred
} from "generated";
const { MockDb, MockPriceOracle } = TestHelpers;

describe("MockPriceOracle contract OwnershipTransferred event tests", () => {
  // Create mock db
  const mockDb = MockDb.createMockDb();

  // Creating mock for MockPriceOracle contract OwnershipTransferred event
  const event = MockPriceOracle.OwnershipTransferred.createMockEvent({/* It mocks event fields with default values. You can overwrite them if you need */});

  it("MockPriceOracle_OwnershipTransferred is created correctly", async () => {
    // Processing the event
    const mockDbUpdated = await MockPriceOracle.OwnershipTransferred.processEvent({
      event,
      mockDb,
    });

    // Getting the actual entity from the mock database
    let actualMockPriceOracleOwnershipTransferred = mockDbUpdated.entities.MockPriceOracle_OwnershipTransferred.get(
      `${event.chainId}_${event.block.number}_${event.logIndex}`
    );

    // Creating the expected entity
    const expectedMockPriceOracleOwnershipTransferred: MockPriceOracle_OwnershipTransferred = {
      id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
      previousOwner: event.params.previousOwner,
      newOwner: event.params.newOwner,
    };
    // Asserting that the entity in the mock database is the same as the expected entity
    assert.deepEqual(actualMockPriceOracleOwnershipTransferred, expectedMockPriceOracleOwnershipTransferred, "Actual MockPriceOracleOwnershipTransferred should be the same as the expectedMockPriceOracleOwnershipTransferred");
  });
});
