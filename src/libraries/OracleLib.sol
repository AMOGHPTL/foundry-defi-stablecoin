// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Amogh patil
 * @notice This library is used to check Chainlink Oracle for stale data.
 * If the price is stale, The function will revert, and render the DSCEngine unusable - This is by design
 * We want the DSCEngine to freeze if the prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol...too bad
 */

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIME_OUT = 3 hours; // 3*60*60 = 10800 seconds

    function stalePriceCheckForLatestRoundData(AggregatorV3Interface PriceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            PriceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;

        if (secondsSince > TIME_OUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
