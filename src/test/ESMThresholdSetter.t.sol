pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";
import {ESM} from "esm/ESM.sol";

import {ESMThresholdSetter} from "../ESMThresholdSetter.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract GlobalSettlementMock {
    uint256 public contractEnabled;

    constructor() public { contractEnabled = 1; }
    function shutdownSystem() public { contractEnabled = 0; }
}
contract ESMThresholdSetterTest is DSTest {
    Hevm hevm;

    DSDelegateToken token;
    ESM esm;
    ESMThresholdSetter setter;
    GlobalSettlementMock globalSettlement;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        token  = new DSDelegateToken("PROT", "PROT");
        token.mint(address(this), 1000000E18);

        globalSettlement = new GlobalSettlementMock();
        setter = new ESMThresholdSetter(address(token), 1E18, 70);
        esm    = new ESM(address(token), address(globalSettlement), address(0x1), address(setter), 70000E18);

        setter.modifyParameters("esm", address(esm));
        esm.addAuthorization(address(setter));
        esm.modifyParameters("thresholdSetter", address(setter));
    }

    function test_setup() public {
        assertEq(address(setter.esm()), address(esm));
        assertEq(address(setter.protocolToken()), address(token));
        assertEq(setter.minAmountToBurn(), 1E18);
        assertEq(setter.supplyPercentageToBurn(), 70);
        assertEq(esm.triggerThreshold(), 70000E18);
    }
    function test_burn_once_recompute() public {
        assertEq(esm.triggerThreshold(), 70000E18);
        token.burn(address(this), 50000E18);
        assertEq(token.totalSupply(), 950000E18);

        setter.recomputeThreshold();
        assertEq(esm.triggerThreshold(), 66500E18);
    }
    function test_mint_once_recompute() public {
        assertEq(esm.triggerThreshold(), 70000E18);
        token.mint(address(this), 150000E18);
        assertEq(token.totalSupply(), 1150000E18);

        setter.recomputeThreshold();
        assertEq(esm.triggerThreshold(), 80500E18);
    }
    function test_burn_twice_recompute() public {
        assertEq(esm.triggerThreshold(), 70000E18);

        token.burn(address(this), 50000E18);
        assertEq(token.totalSupply(), 950000E18);
        setter.recomputeThreshold();

        token.burn(address(this), 50000E18);
        assertEq(token.totalSupply(), 900000E18);
        setter.recomputeThreshold();

        assertEq(esm.triggerThreshold(), 63000E18);
    }
    function testFail_burn_all_recompute() public {
        token.burn(address(this), token.balanceOf(address(this)));
        assertEq(token.totalSupply(), 0);
        setter.recomputeThreshold();
    }
    function test_send_to_zero() public {
        token.transfer(address(0), 500000E18);
        assertEq(token.totalSupply(), 1000000E18);
        setter.recomputeThreshold();

        assertEq(esm.triggerThreshold(), 35000E18);
    }
    function test_send_to_zero_mint() public {
        token.transfer(address(0), 500000E18);
        token.mint(address(this), 500000E18);
        assertEq(token.totalSupply(), 1500000E18);
        setter.recomputeThreshold();

        assertEq(esm.triggerThreshold(), 70000E18);
    }
    function test_mint_twice_recompute() public {
        assertEq(esm.triggerThreshold(), 70000E18);
        token.mint(address(this), 150000E18);
        assertEq(token.totalSupply(), 1150000E18);
        setter.recomputeThreshold();

        token.mint(address(this), 150000E18);
        assertEq(token.totalSupply(), 1300000E18);
        setter.recomputeThreshold();

        assertEq(esm.triggerThreshold(), 91000E18);
    }
    function testFail_recompute_after_settlement() public {
        token.approve(address(esm), uint(-1));
        esm.shutdown();
        assertEq(globalSettlement.contractEnabled(), 0);

        assertEq(esm.triggerThreshold(), 70000E18);
        setter.recomputeThreshold();
    }
}
