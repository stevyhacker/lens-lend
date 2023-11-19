// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { LensLend } from "../src/LensLend.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}


contract LensLendTest is PRBTest, StdCheats {
    LensLend internal lensLend;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        lensLend = new LensLend(
            address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359), // USDC on Polygon
            address(0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d), // Lens Profile Collection on Polygon
            address("todo deploy the aggregator contract and paste the address here")
        );

        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            revert("API_KEY_ALCHEMY not set");
        }

        //run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "polygon", blockNumber: 50_130_288 });
    }

    /// @dev Fork test that runs against an Ethereum Mainnet fork. For this to work, you need to set `API_KEY_ALCHEMY`
    /// in your environment You can get an API key for free at https://alchemy.com.
    function testFork_Example() external {

        address expectedUsdc = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        address expectedLensProfile = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;

        console2.log("lensLend address is %s", address(lensLend));

        address actualLensProfile = address(lensLend.lensProfileCollection());
        address actualUsdc = address(lensLend.usdc());
//        uint256 actualBalance = IERC20(usdc).balanceOf(holder);

        assertEq(actualUsdc, expectedUsdc);
        assertEq(actualLensProfile, expectedLensProfile);
    }
}
