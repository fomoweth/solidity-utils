// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/Uniswap/V3/IUniswapV3Pool.sol";
import "./FixedPoint96.sol";
import "./LiquidityAmounts.sol";
import "./SafeCast.sol";
import "./SwapMath.sol";
import "./TickBitmap.sol";
import "./TickMath.sol";

library PoolMath {
    using SafeCast for uint256;
    using SafeCast for int256;

    error AmountSpecifiedZero();
    error SqrtPriceLimitOutOfBounds();

    struct SwapState {
        int256 amountSpecifiedRemaining;
        int256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
    }

    struct StepComputations {
        uint160 sqrtPriceStartX96;
        int24 tickNext;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
    }

    function computeAmountOut(
        IUniswapV3Pool pool,
        bool zeroForOne,
        int256 amountSpecified
    ) internal view returns (uint256 amountOut) {
        if (amountSpecified == 0) revert AmountSpecifiedZero();

        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
        uint24 fee = pool.fee();
        int24 tickSpacing = pool.tickSpacing();

        bool exactInput = amountSpecified > 0;

        uint160 sqrtPriceLimitX96 = zeroForOne
            ? TickMath.MIN_SQRT_RATIO + 1
            : TickMath.MAX_SQRT_RATIO - 1;

        require(
            zeroForOne
                ? sqrtPriceLimitX96 < sqrtPriceX96 &&
                    sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > sqrtPriceX96 &&
                    sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO
        );

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            liquidity: pool.liquidity()
        });

        while (
            state.amountSpecifiedRemaining != 0 &&
            state.sqrtPriceX96 != sqrtPriceLimitX96
        ) {
            StepComputations memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (
                step.tickNext,
                step.initialized,
                step.sqrtPriceNextX96
            ) = TickBitmap.nextInitializedTickWithinOneWord(
                pool,
                state.tick,
                tickSpacing,
                zeroForOne
            );

            (
                state.sqrtPriceX96,
                step.amountIn,
                step.amountOut,
                step.feeAmount
            ) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (
                    zeroForOne
                        ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > sqrtPriceLimitX96
                )
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            if (exactInput) {
                unchecked {
                    state.amountSpecifiedRemaining =
                        state.amountSpecifiedRemaining -
                        (step.amountIn + step.feeAmount).toInt256();
                }

                state.amountCalculated =
                    state.amountCalculated -
                    step.amountOut.toInt256();
            } else {
                unchecked {
                    state.amountSpecifiedRemaining =
                        state.amountSpecifiedRemaining +
                        step.amountOut.toInt256();
                }

                state.amountCalculated =
                    state.amountCalculated +
                    (step.amountIn + step.feeAmount).toInt256();
            }

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    (, int128 liquidityNet, , , , , , ) = pool.ticks(
                        step.tickNext
                    );

                    unchecked {
                        if (zeroForOne) liquidityNet = -liquidityNet;
                    }

                    state.liquidity = liquidityNet < 0
                        ? state.liquidity - uint128(-liquidityNet)
                        : state.liquidity + uint128(liquidityNet);
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        unchecked {
            (int256 amount0, int256 amount1) = zeroForOne == exactInput
                ? (
                    amountSpecified - state.amountSpecifiedRemaining,
                    state.amountCalculated
                )
                : (
                    state.amountCalculated,
                    amountSpecified - state.amountSpecifiedRemaining
                );

            amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        }
    }

    function computeSwapAmountToRatio(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        view
        returns (uint256 amount0, uint256 amount1, uint256 priceX96)
    {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint256 amountRatioX96;
        uint256 delta0;
        bool zeroForOne;

        amount0 = amount0Desired;
        amount1 = amount1Desired;

        priceX96 = (uint256(sqrtPriceX96) * (sqrtPriceX96)) / FixedPoint96.Q96;

        (uint256 positionAmount0, uint256 positionAmount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                FixedPoint96.Q96.toUint128()
            );

        if (positionAmount0 == 0) {
            delta0 = amount0;
            zeroForOne = true;
        } else if (positionAmount1 == 0) {
            delta0 = FullMath.mulDiv(amount1, FixedPoint96.Q96, priceX96);
            zeroForOne = false;
        } else {
            amountRatioX96 = FullMath.mulDiv(
                positionAmount0,
                FixedPoint96.Q96,
                positionAmount1
            );

            zeroForOne = amountRatioX96 * amount1 < amount0 * FixedPoint96.Q96;

            if (zeroForOne) {
                delta0 =
                    (amount0 * FixedPoint96.Q96 - amountRatioX96 * amount1) /
                    (FullMath.mulDiv(
                        amountRatioX96,
                        priceX96,
                        FixedPoint96.Q96
                    ) + FixedPoint96.Q96);
            } else {
                delta0 =
                    (amountRatioX96 * amount1 - amount0 * FixedPoint96.Q96) /
                    (FullMath.mulDiv(
                        amountRatioX96,
                        priceX96,
                        FixedPoint96.Q96
                    ) + FixedPoint96.Q96);
            }
        }

        if (delta0 != 0) {
            uint256 amountOut;

            if (zeroForOne) {
                amountOut = computeAmountOut(pool, true, delta0.toInt256());
                amount0 = amount0 - delta0;
                amount1 = amount1 + amountOut;
            } else {
                uint256 delta1 = FullMath.mulDiv(
                    delta0,
                    priceX96,
                    FixedPoint96.Q96
                );
                amountOut = computeAmountOut(pool, false, delta1.toInt256());
                amount0 = amount0 + amountOut;
                amount1 = amount1 - delta1;
            }
        }
    }
}
