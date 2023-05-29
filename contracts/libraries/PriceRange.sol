// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/Uniswap/V3/IUniswapV3Pool.sol";
import "./FixedPoint96.sol";
import "./FullMath.sol";
import "./PercentageMath.sol";
import "./TickMath.sol";

enum Assumption {
    Bullish,
    Bearish,
    Neutral
}

enum Duration {
    Day,
    Week,
    Month,
    Year
}

library PriceRange {
    int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;
    int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function computePriceRange(
        Assumption assumption,
        Duration duration,
        uint256 priceCurrent
    ) internal pure returns (uint256 priceLower, uint256 priceUpper) {
        uint256 r = scalingFactor(duration);

        if (assumption == Assumption.Bullish) {
            priceLower = priceCurrent;
            priceUpper = PercentageMath.percentMul(
                priceCurrent,
                FullMath.mulDiv(r, r, PercentageMath.PERCENTAGE_FACTOR)
            );
        } else if (assumption == Assumption.Bearish) {
            priceLower = PercentageMath.percentDiv(
                priceCurrent,
                FullMath.mulDiv(r, r, PercentageMath.PERCENTAGE_FACTOR)
            );
            priceUpper = priceCurrent;
        } else {
            priceLower = PercentageMath.percentDiv(priceCurrent, r);
            priceUpper = PercentageMath.percentMul(priceCurrent, r);
        }
    }

    function getTicks(
        uint256 priceLower,
        uint256 priceUpper,
        int24 tickSpacing,
        uint8 decimals0
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        tickLower = priceToTick(priceLower, tickSpacing, decimals0);
        tickUpper = priceToTick(priceUpper, tickSpacing, decimals0);
    }

    function encodeSqrtRatioX96(
        uint256 price,
        uint8 decimals0
    ) internal pure returns (uint160) {
        return
            uint160(
                (FullMath.sqrt(price * 10 ** decimals0) * (2 ** 96)) /
                    10 ** decimals0
            );
    }

    function roundedTick(
        int24 tick,
        int24 tickSpacing
    ) private pure returns (int24 rounded) {
        rounded = int24(divRound(tick, tickSpacing)) * tickSpacing;

        if (rounded < TickMath.MIN_TICK) rounded += tickSpacing;
        else if (rounded > TickMath.MAX_TICK) rounded -= tickSpacing;
    }

    function priceToTick(
        uint256 price,
        int24 tickSpacing,
        uint8 decimals0
    ) private pure returns (int24) {
        int24 tick = TickMath.getTickAtSqrtRatio(
            encodeSqrtRatioX96(price, decimals0)
        );

        return roundedTick(tick, tickSpacing);
    }

    function div(int128 x, int128 y) private pure returns (int128) {
        unchecked {
            require(y != 0);
            int256 z = (int256(x) << 64) / y;
            require(z >= MIN_64x64 && z <= MAX_64x64);
            return int128(z);
        }
    }

    function divRound(int128 x, int128 y) private pure returns (int128 z) {
        z = div(x, y) >> 64;

        if (z % 2 ** 64 >= 0x8000000000000000) {
            z += 1;
        }
    }

    function scalingFactor(Duration duration) private pure returns (uint256 r) {
        if (duration == Duration.Day) r = 10650;
        else if (duration == Duration.Week) r = 11750;
        else if (duration == Duration.Month) r = 14000;
        else if (duration == Duration.Year) r = 32500;
    }
}
