## Testing strategy for Molten Campaigns and Elections

Tests on Campaigns and Elections are written in the most unitary way as
possible using Forge.

For example when checking that the `stake` function transfers tokens from the
message sender to the Campaign, we simply check that the `stake` function has
been doing a call to `transferFrom` function with proper arguments:

```solidity
function testStakeCallsTransfer() public {
  vm.prank(staker);
  mc.stake(333);

  (address from, address to, uint256 amount) = daoToken
    .transferFromCalledWith();
  assertEq(from, staker);
  assertEq(to, address(mc));
  assertEq(amount, 333);
}

```

We leave it to the OpenZeppelin codebase to include tests on ERC20.sol (on which
we depend), including tests on `transferFrom`. This lib is doing this precise
job better than we'll ever do, as it's their responsibility.

## Mocking and dependency injection

Such _properly unit_ tests are testing against the interface of the `ERC20`
smart contract. This produces produce as much safety as integrated tests (which
would call the real `transferFrom` and check its results) all the while
preventing any combinatorial explosion in the number of test cases that would
result from testing two things at the same time (our function behavior and the
underlying behavior of `transferFrom`).

To write such tests, we are using hand-made mocks. When these mocks are
dependency-injected (in the constructor of the smart contract under test, for
example), this works smoothly.

⚠️ But where dependency injection is not used (too costly or complex) it is
necessary to replicate some setup code from the actual contracts to the test
contracts. Care must be given to properly update these test setups when
contracts change.

### Other possible approach

Another approach would be to use an abstract contract on our smart contracts,
that would be used in tests but removed from production code. Meaning: code
rewrite for production, but tightly controlled.

This way, mocks would be set during test setups via for example `function
setMTokenMock(IERC20)`, but these functions wouldn't be available in production.

Of couse the problem then lies in how reliable would code rewrite be. To be
tried.
