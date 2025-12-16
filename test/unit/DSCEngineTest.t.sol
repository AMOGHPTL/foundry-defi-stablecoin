//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 50 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////////
    ///////////Price Tests///////
    //////////////////////////////

    function testGetUsdValue() public view {
        uint256 ETH_AMOUNT = 15e18;
        uint256 expectedUsdValue = 2000 * 15e18;

        uint256 actualUsdValue = engine.getUsdValue(weth, ETH_AMOUNT);
        assertEq(actualUsdValue, expectedUsdValue);
    }

    ///////////////////////////////////////////
    ///////////Depposit Collateral Tests///////
    ///////////////////////////////////////////

    function testDepositRevertsIfAmountIsZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MoreThanZero.selector);
        engine.depositCollateral(weth, 0);
    }

    function testDepositRevertsIfTokenIsNotAllowed() public {
        uint256 ETH_AMOUNT = 15e18;
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(3), ETH_AMOUNT);
    }

    function testUserCanDeposit() public {
        uint256 ETH_AMOUNT = 8 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, ETH_AMOUNT);
        vm.stopPrank();
    }
}
