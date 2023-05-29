// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/Uniswap/V3/IUniswapV3Pool.sol";
import "./BitMath.sol";
import "./SafeCast.sol";
import "./TickMath.sol";

library TickBitmap {
    using SafeCast for uint8;

    function position(
        int24 tick
    ) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(int8(tick % 256));
    }

    function nextInitializedTickWithinOneWord(
        IUniswapV3Pool pool,
        int24 tick,
        int24 tickSpacing,
        bool lte
    )
        internal
        view
        returns (int24 tickNext, bool initialized, uint160 sqrtPriceNextX96)
    {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) --compressed;

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            initialized = masked != 0;
            tickNext = initialized
                ? (compressed -
                    (bitPos - BitMath.mostSignificantBit(masked)).toInt24()) *
                    tickSpacing
                : (compressed - bitPos.toInt24()) * tickSpacing;
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            initialized = masked != 0;
            tickNext = initialized
                ? (compressed +
                    1 +
                    (BitMath.leastSignificantBit(masked) - bitPos).toInt24()) *
                    tickSpacing
                : (compressed + 1 + (type(uint8).max - bitPos).toInt24()) *
                    tickSpacing;
        }

        if (tickNext < TickMath.MIN_TICK) {
            tickNext = TickMath.MIN_TICK;
        } else if (tickNext > TickMath.MAX_TICK) {
            tickNext = TickMath.MAX_TICK;
        }

        sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(tickNext);
    }
}
