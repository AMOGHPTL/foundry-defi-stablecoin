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
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 100 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 150 ether;
    uint256 public constant AMOUNT_TO_MINT = 10 ether;
    uint256 public constant BREAKING_MINT_AMOUNT = 110000 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
    }

    //////////////////////////////
    ///////Constructor Tests//////
    //////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddress;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddress.push(wethUsdPriceFeed);
        priceFeedAddress.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAdressesMustBeOfSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddress, address(dsc));
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

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
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
        ERC20Mock ranToken = new ERC20Mock();
        ranToken.mint(USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testUserCanDeposit() public {
        uint256 ETH_AMOUNT = 8 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, ETH_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfUserDoesNotHaveEnoughBalance() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert();
        engine.depositCollateral(weth, AMOUNT_COLLATERAL + 1 ether);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(expectedTotalDscMinted, totalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    //////////////////////////////////////////////////////////
    //////////////Deposit collateral & Mint DSC///////////////
    //////////////////////////////////////////////////////////

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 balance = dsc.balanceOf(USER);
        assertEq(balance, AMOUNT_TO_MINT);
    }

    ///////////////////////////////////////////
    //////////////Mint DSC Tests///////////////
    ///////////////////////////////////////////

    function testMintRevertsIfAmountIsZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MoreThanZero.selector);
        engine.mintDsc(0);
    }

    function testRevertIfHealthFactorIsBroken() public depositedCollateralAndMintedDsc {
        uint256 startingHealthFactor = engine.healthFactor(USER);
        vm.startPrank(USER);
        // uint256 endingHealthFactor = engine.healthFactor(USER);
        vm.expectRevert();
        engine.mintDsc(BREAKING_MINT_AMOUNT);
        vm.stopPrank();
    }

    ///////////////////////////////////////////
    ////////redeem collateral Tests////////////
    ///////////////////////////////////////////

    function testRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////////////////////////////
    ////////redeem collateral for DSC Tests////////////
    ///////////////////////////////////////////////////

    function testUserCanredeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        uint256 startingBalance = dsc.balanceOf(USER);
        vm.startPrank(USER);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        uint256 endingBalance = dsc.balanceOf(USER);
        assertEq(endingBalance, 0);
        assert(startingBalance > endingBalance);
    }

    ///////////////////////////////////////////
    //////////////Burn DSC Tests///////////////
    ///////////////////////////////////////////

    function testUserCanBurnDsc() public depositedCollateralAndMintedDsc {
        uint256 startingBalance = dsc.balanceOf(USER);
        vm.startPrank(USER);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        engine.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
        uint256 endingBalance = dsc.balanceOf(USER);
        assertEq(endingBalance, 0);
        assert(startingBalance > 0);
    }

    ////////////////////////////////////////////
    //////////////Liquidate Tests///////////////
    ////////////////////////////////////////////

    modifier depositedCollateralAndMintedDscBreakingHealthFactor() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert();
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, BREAKING_MINT_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier liquidatorDepositAndMintedDsc() {
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testUserCanNotBeLiquidatedIfHealthFactorIsOk() public depositedCollateralAndMintedDsc {
        vm.startPrank(LIQUIDATOR);
        engine.healthFactor(USER);
        dsc.approve(address(engine), AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
        uint256 healthFactor = engine.healthFactor(USER);
    }
}
