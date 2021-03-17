pragma solidity 0.6.7;

import "./ESMThresholdSetterMock.sol";

contract ESMMock {
    uint256 public triggerThreshold;

    constructor(uint256 threshold) public {
        triggerThreshold = threshold;
    }

    function settled() virtual public returns (uint256) {
        return 0;
    }
    function modifyParameters(bytes32, uint256 _triggerThreshold) public {
        triggerThreshold = _triggerThreshold;
    }
}

contract TokenMock {
    uint256 public totalSupply = 1E24;
    uint256 public burnedBalance;

    function balanceOf(address) public returns (uint) {
        return burnedBalance;
    }

    function setParams(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }
}

// @notice Fuzz the whole thing, failures will show bounds (run with checkAsserts: on)
contract FuzzBounds is ESMThresholdSetterMock {
    constructor() public ESMThresholdSetterMock(
        address(new TokenMock()),
        1E18, // minAmountTopBurn
        70    // supplyPercentageToBurn
    ) {
        esm = ESMLike(address(new ESMMock(1E18)));
    }

    function fuzzParams(uint256 totalSupply) public {
        TokenMock(address(protocolToken)).setParams(totalSupply);
    }
}

// @notice Fuzz the contracts testing properties
contract Fuzz is ESMThresholdSetterMock {
    uint256 lastUpdateTotalSupply;
    constructor() public ESMThresholdSetterMock(
        address(new TokenMock()),
        1E18, // minAmountTopBurn
        70    // supplyPercentageToBurn
    ) {
        esm = ESMLike(address(new ESMMock(1E18)));
    }

    function fuzzParams(uint256 totalSupply) public {
        TokenMock(address(protocolToken)).setParams(totalSupply);
    }

    function recomputeThreshold() public override {
        lastUpdateTotalSupply = protocolToken.totalSupply();
        super.recomputeThreshold();
    }    

    // properties   
    function echidna_minAmountToBurn() public returns (bool) { 
        return minAmountToBurn == 1E18;
    }

    function echidna_supplyPercentageToBurn() public returns (bool) { 
        return supplyPercentageToBurn == 70;
    }

    function echidna_threshold() public returns (bool) {
        uint threshold = ESMMock(address(esm)).triggerThreshold();
        if (threshold < minAmountToBurn) return false;
        if (threshold == minAmountToBurn) return true;
        if (
             threshold != (lastUpdateTotalSupply * supplyPercentageToBurn) / 1000 // burned tokens are always 0
        ) return false;
        return true;
    }
}

// @notice Will create several different ThresholdSetters.
// goal is to fuzz minAmountToBurn and supplyPercentageToBurn
contract ExternalFuzz {
    ESMThresholdSetterMock setter;
    ESMMock esm;
    TokenMock token;

    uint256 lastUpdateTotalSupply;

    constructor() public  {
        token = new TokenMock();
        esm = new ESMMock(1E18);
        createNewSetter(1E18, 65); 
    }

    function fuzzTotalSupply(uint256 totalSupply) public {
        token.setParams(totalSupply);
    }

    function createNewSetter(uint256 minAmountToBurn, uint256 supplyPercentageToBurn) public {
        setter = new ESMThresholdSetterMock(
            address(token),
            minAmountToBurn + 1,
            (supplyPercentageToBurn % 999) + 1 // ensuring valid setter params
        );
        setter.modifyParameters("esm", address(esm));
        recomputeThreshold();
    }    

    function recomputeThreshold() public {
        lastUpdateTotalSupply = token.totalSupply();
        setter.recomputeThreshold();
    }    

    // properties
    function echidna_threshold() public returns (bool) {
        uint threshold = esm.triggerThreshold();
        if (threshold < setter.minAmountToBurn()) return false;
        if (threshold == setter.minAmountToBurn()) return true;
        if (
             threshold != (lastUpdateTotalSupply * setter.supplyPercentageToBurn()) / 1000 // burned tokens are always 0
        ) return false;
        return true;
    }
}

