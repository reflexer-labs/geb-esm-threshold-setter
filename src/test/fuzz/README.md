# Security Tests

The contracts in this folder are the fuzz scripts for the ESM Threshold Setter.

To run the fuzzer, set up Echidna (https://github.com/crytic/echidna) on your machine.

Then run
```
echidna-test src/test/fuzz/<name of file>.sol --contract <Name of contract> --config src/test/fuzz/echidna.yaml
```

Configs are in this folder (echidna.yaml). 

The contracts in this folder are modified versions of the originals in the _src_ folder. They have assertions added to test for invariants, visibility of functions modified. Running the Fuzz against modified versions without the assertions is still possible, general properties on the Fuzz contract can be executed against unmodified contracts.

Tests should be run one at a time because they interfere with each other.

For all contracts being fuzzed, we tested the following:

1. Writing assertions and/or turning "requires" into "asserts" within the smart contract itself. This will cause echidna to fail fuzzing, and upon failures echidna finds the lowest value that causes the assertion to fail. This is useful to test bounds of functions (i.e.: modifying safeMath functions to assertions will cause echidna to fail on overflows, giving insight on the bounds acceptable). This is useful to find out when these functions revert. Although reverting will not impact the contract's state, it could cause a denial of service (or the contract not updating state when necessary and getting stuck). We check the found bounds against the expected usage of the system.
2. For contracts that have state (i.e.: the auction house below), we also force the contract into common states and fuzz common actions like bidding, or starting auctions (and then bidding the hell out of them).

Echidna will generate random values and call all functions failing either for violated assertions, or for properties (functions starting with echidna_) that return false. Sequence of calls is limited by seqLen in the config file. Calls are also spaced over time (both block number and timestamp) in random ways. Once the fuzzer finds a new execution path, it will explore it by trying execution with values close to the ones that opened the new path.

# Results

### 1. Fuzzing for overflows (FuzzBounds)

In this test we want failures, as they will show us what are the bounds in which the contract operates safely.

This will fuzz the contract with one auction open, we then fuzz all functions with varying totalSuply. 

Failures flag where overflows happen, and should be compared to expected inputs (to avoid overflows frm causing DoS). Only Failures are listed below:

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-esm-threshold-setter/src/test/fuzz/ESMThresholdSetterFuzz.sol:FuzzBounds
assertion in minAmountToBurn: passed! 🎉
assertion in setUp: passed! 🎉
assertion in protocolToken: passed! 🎉
assertion in authorizedAccounts: passed! 🎉
assertion in addAuthorization: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in recomputeThreshold: failed!💥  
  Call sequence:
    fuzzParams(1665447104599733097844926055494893500052037430788859830057905524238391824131)
    recomputeThreshold()

assertion in removeAuthorization: passed! 🎉
assertion in esm: passed! 🎉
assertion in fuzzParams: passed! 🎉
assertion in supplyPercentageToBurn: passed! 🎉

Seed: 7604164954251917915
```
Overflows for calls with a circulating supply (totalSupply - burnedTokens) of 1,665,447,104,599,733,097,844,926,055,494,893,500,052,037,430,788,859,830,057.905524238391824131

#### Conclusion: No issues noted, bounds are plentiful even on the most extreme expected scenarios.


### Fuzz Properties (Fuzz)

In this case we setup the setter, and check properties.

Here we are not looking for bounds, but instead checking the properties that either should remain constant, or that move as the auction evolves:

- minAmountToBurn remains constant
- supplyPercentaeToBurn remains constant
- threshold < minAmountToBurn
- threshold is correctly calculated, correclty set in the ESM

These properties are verified in between all calls.

We fuzzed the totalSupply as in the first test.

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-esm-threshold-setter/src/test/fuzz/ESMThresholdSetterFuzz.sol:Fuzz
echidna_supplyPercentageToBurn: passed! 🎉
echidna_minAmountToBurn: passed! 🎉
echidna_threshold: passed! 🎉

Seed: 2417060937278575774
```

#### Conclusion: No issues noted.


### Fuzz minAmountToBurn/supplyPercentageToBurn (ExternalFuzz)

In this campaign we will deploy an external ESM Threshold Setter, instead of fuzzing from within as we usually do.

This is because minAmountToBurn and supplyPercentageToBurn are set at deployment and remain constant for the life of the contract.

We will fuzz the creation of Threshold Setters, and then fuzz them against the threshold properties.

This test should be run with seqLen set to a high amont (we used 1000).
```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-esm-threshold-setter/src/test/fuzz/ESMThresholdSetterFuzz.sol:ExternalFuzz
echidna_threshold: passed! 🎉

Seed: -5706020860580365979
```

#### Conclusion: No exceptions found.

