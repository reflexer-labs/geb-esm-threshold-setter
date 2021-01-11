pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebEsmThresholdSetter.sol";

contract GebEsmThresholdSetterTest is DSTest {
    GebEsmThresholdSetter setter;

    function setUp() public {
        setter = new GebEsmThresholdSetter();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
