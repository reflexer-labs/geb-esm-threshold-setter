pragma solidity 0.6.7;

abstract contract ESMLike {
    function contractEnabled() virtual public view returns (uint256);
    function modifyParameters(bytes32, uint256) virtual external;
}
abstract contract ProtocolTokenLike {
    function balanceOf(address) virtual public view returns (uint256);
    function totalSupply() virtual public view returns (uint256);
}

contract ESMThresholdSetter {
    // --- Variables ---
    uint256           public minAmountToBurn;         // [wad]
    uint256           public supplyPercentageToBurn;  // [thousand]

    ProtocolTokenLike public protocolToken;
    ESMLike           public esm;

    constructor(
      address protocolToken_,
      address esm_,
      uint256 minAmountToBurn_,
      uint256 supplyPercentageToBurn_
    ) public {
        require(protocolToken_ != address(0), "ESMThresholdSetter/");
        require(esm_ != address(0), "ESMThresholdSetter/null-esm");
        require(both(supplyPercentageToBurn_ > 0, supplyPercentageToBurn_ < THOUSAND), "ESMThresholdSetter/invalid-percentage-to-burn");
        require(minAmountToBurn_ > 0, "ESMThresholdSetter/null-min-amount-to-burn");

        minAmountToBurn        = minAmountToBurn_;
        supplyPercentageToBurn = supplyPercentageToBurn_;
        esm                    = ESMLike(esm_);
        protocolToken          = ProtocolTokenLike(protocolToken_);

        require(esm.contractEnabled() == 1, "ESMThresholdSetter/esm-disabled");
        require(protocolToken.totalSupply() > 0, "ESMThresholdSetter/null-token-supply");
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Math ---
    uint256 constant THOUSAND = 10 ** 3;
    function maximum(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x >= y) ? x : y;
    }
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ESMThresholdSetter/sub-uint-uint-underflow");
    }
    function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ESMThresholdSetter/multiply-uint-uint-overflow");
    }

    function recomputeThreshold() public {
        require(esm.contractEnabled() == 1, "ESMThresholdSetter/esm-disabled");

        uint256 currentTokenSupply = protocolToken.totalSupply();
        if (currentTokenSupply == 0) {
          esm.modifyParameters("triggerThreshold", minAmountToBurn);
        }

        uint256 newThreshold = multiply(subtract(currentTokenSupply, protocolToken.balanceOf(address(0))), supplyPercentageToBurn) / THOUSAND;
        esm.modifyParameters("triggerThreshold", maximum(minAmountToBurn, newThreshold));
    }
}
