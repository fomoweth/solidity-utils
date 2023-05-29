// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./SignedDecimalMath.sol";
import "./DecimalMath.sol";
import "./FixedPointMath.sol";

library BlackScholes {
    using DecimalMath for uint;
    using SignedDecimalMath for int;

    struct PricesDeltaStdVega {
        uint callPrice;
        uint putPrice;
        int callDelta;
        int putDelta;
        uint vega;
        uint stdVega;
    }

    /**
     * @param timeToExpirySec Number of seconds to the expiry of the option
     * @param volatilityDecimal Implied volatility over the period til expiry as a percentage
     * @param spotDecimal The current price of the base asset
     * @param strikePriceDecimal The strikePrice price of the option
     * @param rateDecimal The percentage risk free rate + carry cost
     */
    struct BlackScholesParams {
        uint timeToExpirySec;
        uint volatilityDecimal;
        uint spotDecimal;
        uint strikePriceDecimal;
        int rateDecimal;
    }

    uint private constant SECONDS_PER_YEAR = 31536000;
    /// @dev Internally this library uses 27 decimals of precision
    uint private constant PRECISE_UNIT = 1e27;
    uint private constant SQRT_TWOPI = 2506628274631000502415765285;
    /// @dev Below this value, return 0
    int private constant MIN_CDF_STD_DIST_INPUT =
        (int(PRECISE_UNIT) * -45) / 10; // -4.5
    /// @dev Above this value, return 1
    int private constant MAX_CDF_STD_DIST_INPUT = int(PRECISE_UNIT) * 10;
    /// @dev Value to use to avoid any division by 0 or values near 0
    uint private constant MIN_T_ANNUALISED = PRECISE_UNIT / SECONDS_PER_YEAR; // 1 second
    uint private constant MIN_VOLATILITY = PRECISE_UNIT / 10000; // 0.001%
    uint private constant VEGA_STANDARDISATION_MIN_DAYS = 7 days;
    /// @dev Magic numbers for normal CDF
    uint private constant SPLIT = 7071067811865470000000000000;
    uint private constant N0 = 220206867912376000000000000000;
    uint private constant N1 = 221213596169931000000000000000;
    uint private constant N2 = 112079291497871000000000000000;
    uint private constant N3 = 33912866078383000000000000000;
    uint private constant N4 = 6373962203531650000000000000;
    uint private constant N5 = 700383064443688000000000000;
    uint private constant N6 = 35262496599891100000000000;
    uint private constant M0 = 440413735824752000000000000000;
    uint private constant M1 = 793826512519948000000000000000;
    uint private constant M2 = 637333633378831000000000000000;
    uint private constant M3 = 296564248779674000000000000000;
    uint private constant M4 = 86780732202946100000000000000;
    uint private constant M5 = 16064177579207000000000000000;
    uint private constant M6 = 1755667163182640000000000000;
    uint private constant M7 = 88388347648318400000000000;

    /////////////////////////////////////
    // Option Pricing public functions //
    /////////////////////////////////////

    /**
     * @dev Returns call and put prices for options with given parameters.
     */
    function quote(
        BlackScholesParams memory bs
    ) internal pure returns (uint call, uint put) {
        uint tAnnualised = annualise(bs.timeToExpirySec);
        uint spotPrecise = bs.spotDecimal.decimalToPreciseDecimal();
        uint strikePricePrecise = bs
            .strikePriceDecimal
            .decimalToPreciseDecimal();
        int ratePrecise = bs.rateDecimal.decimalToPreciseDecimal();

        (int d1, int d2) = derivatives(
            tAnnualised,
            bs.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            strikePricePrecise,
            ratePrecise
        );

        (call, put) = _quote(
            tAnnualised,
            spotPrecise,
            strikePricePrecise,
            ratePrecise,
            d1,
            d2
        );

        return (call.preciseDecimalToDecimal(), put.preciseDecimalToDecimal());
    }

    /**
     * @dev Returns call/put prices and delta/stdVega for options with given parameters.
     */
    function pricesDeltaStdVega(
        BlackScholesParams memory bs
    ) internal pure returns (PricesDeltaStdVega memory) {
        uint tAnnualised = annualise(bs.timeToExpirySec);
        uint spotPrecise = bs.spotDecimal.decimalToPreciseDecimal();

        (int d1, int d2) = derivatives(
            tAnnualised,
            bs.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bs.strikePriceDecimal.decimalToPreciseDecimal(),
            bs.rateDecimal.decimalToPreciseDecimal()
        );

        (uint callPrice, uint putPrice) = _quote(
            tAnnualised,
            spotPrecise,
            bs.strikePriceDecimal.decimalToPreciseDecimal(),
            bs.rateDecimal.decimalToPreciseDecimal(),
            d1,
            d2
        );

        (uint vegaPrecise, uint stdVegaPrecise) = standardVega(
            d1,
            spotPrecise,
            bs.timeToExpirySec
        );

        (int callDelta, int putDelta) = _delta(d1);

        return
            PricesDeltaStdVega(
                callPrice.preciseDecimalToDecimal(),
                putPrice.preciseDecimalToDecimal(),
                callDelta.preciseDecimalToDecimal(),
                putDelta.preciseDecimalToDecimal(),
                vegaPrecise.preciseDecimalToDecimal(),
                stdVegaPrecise.preciseDecimalToDecimal()
            );
    }

    /**
     * @dev Returns call delta given parameters.
     */

    function delta(
        BlackScholesParams memory bs
    ) internal pure returns (int callDeltaDecimal, int putDeltaDecimal) {
        uint tAnnualised = annualise(bs.timeToExpirySec);
        uint spotPrecise = bs.spotDecimal.decimalToPreciseDecimal();

        (int d1, ) = derivatives(
            tAnnualised,
            bs.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bs.strikePriceDecimal.decimalToPreciseDecimal(),
            bs.rateDecimal.decimalToPreciseDecimal()
        );

        (int callDelta, int putDelta) = _delta(d1);

        return (
            callDelta.preciseDecimalToDecimal(),
            putDelta.preciseDecimalToDecimal()
        );
    }

    /**
     * @dev Returns non-normalized vega given parameters. Quoted in cents.
     */
    function vega(
        BlackScholesParams memory bs
    ) internal pure returns (uint vegaDecimal) {
        uint tAnnualised = annualise(bs.timeToExpirySec);
        uint spotPrecise = bs.spotDecimal.decimalToPreciseDecimal();

        (int d1, ) = derivatives(
            tAnnualised,
            bs.volatilityDecimal.decimalToPreciseDecimal(),
            spotPrecise,
            bs.strikePriceDecimal.decimalToPreciseDecimal(),
            bs.rateDecimal.decimalToPreciseDecimal()
        );

        return _vega(tAnnualised, spotPrecise, d1).preciseDecimalToDecimal();
    }

    //////////////////////
    // Computing Greeks //
    //////////////////////

    /**
     * @dev Returns internal coefficients of the Black-Scholes call price formula, d1 and d2.
     * @param tAnnualised Number of years to expiry
     * @param volatility Implied volatility over the period til expiry as a percentage
     * @param spot The current price of the base asset
     * @param strikePrice The strikePrice price of the option
     * @param rate The percentage risk free rate + carry cost
     */
    function derivatives(
        uint tAnnualised,
        uint volatility,
        uint spot,
        uint strikePrice,
        int rate
    ) internal pure returns (int d1, int d2) {
        // Set minimum values for tAnnualised and volatility to not break computation in extreme scenarios
        // These values will result in option prices reflecting only the difference in stock/strikePrice, which is expected.
        // This should be caught before calling this function, however the function shouldn't break if the values are 0.
        tAnnualised = tAnnualised < MIN_T_ANNUALISED
            ? MIN_T_ANNUALISED
            : tAnnualised;
        volatility = volatility < MIN_VOLATILITY ? MIN_VOLATILITY : volatility;

        int vtSqrt = int(
            volatility.multiplyDecimalRoundPrecise(sqrtPrecise(tAnnualised))
        );
        int log = FixedPointMath.lnPrecise(
            int(spot.divideDecimalRoundPrecise(strikePrice))
        );
        int v2t = (int(volatility.multiplyDecimalRoundPrecise(volatility) / 2) +
            rate).multiplyDecimalRoundPrecise(int(tAnnualised));

        d1 = (log + v2t).divideDecimalRoundPrecise(vtSqrt);
        d2 = d1 - vtSqrt;
    }

    /**
     * @dev Internal coefficients of the Black-Scholes call price formula.
     * @param tAnnualised Number of years to expiry
     * @param spot The current price of the base asset
     * @param strikePrice The strikePrice price of the option
     * @param rate The percentage risk free rate + carry cost
     * @param d1 Internal coefficient of Black-Scholes
     * @param d2 Internal coefficient of Black-Scholes
     */
    function _quote(
        uint tAnnualised,
        uint spot,
        uint strikePrice,
        int rate,
        int d1,
        int d2
    ) internal pure returns (uint call, uint put) {
        uint strikePricePV = strikePrice.multiplyDecimalRoundPrecise(
            FixedPointMath.expPrecise(
                int(-rate.multiplyDecimalRoundPrecise(int(tAnnualised)))
            )
        );
        uint spotNd1 = spot.multiplyDecimalRoundPrecise(stdNormalCDF(d1));
        uint strikePriceNd2 = strikePricePV.multiplyDecimalRoundPrecise(
            stdNormalCDF(d2)
        );

        // We clamp to zero if the minuend is less than the subtrahend
        // In some scenarios it may be better to compute put price instead and derive call from it depending on which way
        // around is more precise.
        call = strikePriceNd2 <= spotNd1 ? spotNd1 - strikePriceNd2 : 0;
        put = call + strikePricePV;
        put = spot <= put ? put - spot : 0;
    }

    /*
     * Greeks
     */

    /**
     * @dev Returns the option's delta value
     * @param d1 Internal coefficient of Black-Scholes
     */
    function _delta(
        int d1
    ) internal pure returns (int callDelta, int putDelta) {
        callDelta = int(stdNormalCDF(d1));
        putDelta = callDelta - int(PRECISE_UNIT);
    }

    /**
     * @dev Returns the option's vega value based on d1. Quoted in cents.
     *
     * @param d1 Internal coefficient of Black-Scholes
     * @param tAnnualised Number of years to expiry
     * @param spot The current price of the base asset
     */
    function _vega(
        uint tAnnualised,
        uint spot,
        int d1
    ) internal pure returns (uint) {
        return
            sqrtPrecise(tAnnualised).multiplyDecimalRoundPrecise(
                stdNormal(d1).multiplyDecimalRoundPrecise(spot)
            );
    }

    /**
     * @dev Returns the option's vega value with expiry modified to be at least VEGA_STANDARDISATION_MIN_DAYS
     * @param d1 Internal coefficient of Black-Scholes
     * @param spot The current price of the base asset
     * @param timeToExpirySec Number of seconds to expiry
     */
    function standardVega(
        int d1,
        uint spot,
        uint timeToExpirySec
    ) private pure returns (uint, uint) {
        uint tAnnualised = annualise(timeToExpirySec);
        uint normalisationFactor = getVegaNormalisationFactorPrecise(
            timeToExpirySec
        );
        uint vegaPrecise = _vega(tAnnualised, spot, d1);

        return (
            vegaPrecise,
            vegaPrecise.multiplyDecimalRoundPrecise(normalisationFactor)
        );
    }

    function getVegaNormalisationFactorPrecise(
        uint timeToExpirySec
    ) private pure returns (uint) {
        timeToExpirySec = timeToExpirySec < VEGA_STANDARDISATION_MIN_DAYS
            ? VEGA_STANDARDISATION_MIN_DAYS
            : timeToExpirySec;
        uint daysToExpiry = timeToExpirySec / 1 days;
        uint thirty = 30 * PRECISE_UNIT;

        return sqrtPrecise(thirty / daysToExpiry) / 100;
    }

    /////////////////////
    // Math Operations //
    /////////////////////

    /**
     * @dev Compute the absolute value of `val`.
     *
     * @param val The number to absolute value.
     */
    function abs(int val) private pure returns (uint) {
        return uint(val < 0 ? -val : val);
    }

    /// @notice Calculates the square root of x, rounding down (borrowed from https://github.com/paulrberg/prb-math)
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint x) private pure returns (uint result) {
        if (x == 0) return 0;

        // Calculate the square root of the perfect square of a power of two that is the closest to x.
        uint xAux = uint(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }

    /**
     * @dev Returns the square root of the value using Newton's method.
     */
    function sqrtPrecise(uint x) private pure returns (uint) {
        // Add in an extra unit factor for the square root to gobble;
        // otherwise, sqrt(x * UNIT) = sqrt(x) * sqrt(UNIT)
        return sqrt(x * PRECISE_UNIT);
    }

    /**
     * @dev The standard normal distribution of the value.
     */
    function stdNormal(int x) internal pure returns (uint) {
        return
            FixedPointMath
                .expPrecise(int(-x.multiplyDecimalRoundPrecise(x / 2)))
                .divideDecimalRoundPrecise(SQRT_TWOPI);
    }

    /**
     * @dev The standard normal cumulative distribution of the value.
     * borrowed from a C++ implementation https://stackoverflow.com/a/23119456
     */
    function stdNormalCDF(int x) internal pure returns (uint) {
        uint z = abs(x);
        int c;

        if (z <= 37 * PRECISE_UNIT) {
            uint e = FixedPointMath.expPrecise(
                -int(z.multiplyDecimalRoundPrecise(z / 2))
            );

            if (z < SPLIT) {
                c = int(
                    (
                        stdNormalCDFNumerator(z)
                            .divideDecimalRoundPrecise(stdNormalCDFDenom(z))
                            .multiplyDecimalRoundPrecise(e)
                    )
                );
            } else {
                uint f = (z +
                    PRECISE_UNIT.divideDecimalRoundPrecise(
                        z +
                            (2 * PRECISE_UNIT).divideDecimalRoundPrecise(
                                z +
                                    (3 * PRECISE_UNIT)
                                        .divideDecimalRoundPrecise(
                                            z +
                                                (4 * PRECISE_UNIT)
                                                    .divideDecimalRoundPrecise(
                                                        z +
                                                            ((PRECISE_UNIT *
                                                                13) / 20)
                                                    )
                                        )
                            )
                    ));

                c = int(
                    e.divideDecimalRoundPrecise(
                        f.multiplyDecimalRoundPrecise(SQRT_TWOPI)
                    )
                );
            }
        }

        return uint((x <= 0 ? c : (int(PRECISE_UNIT) - c)));
    }

    /**
     * @dev Helper for stdNormalCDF
     */
    function stdNormalCDFNumerator(uint z) private pure returns (uint) {
        uint numeratorInner = ((((((N6 * z) / PRECISE_UNIT + N5) * z) /
            PRECISE_UNIT +
            N4) * z) /
            PRECISE_UNIT +
            N3);

        return
            (((((numeratorInner * z) / PRECISE_UNIT + N2) * z) /
                PRECISE_UNIT +
                N1) * z) /
            PRECISE_UNIT +
            N0;
    }

    /**
     * @dev Helper for stdNormalCDF
     */
    function stdNormalCDFDenom(uint z) private pure returns (uint) {
        uint denominatorInner = ((((((M7 * z) / PRECISE_UNIT + M6) * z) /
            PRECISE_UNIT +
            M5) * z) /
            PRECISE_UNIT +
            M4);

        return
            (((((((denominatorInner * z) / PRECISE_UNIT + M3) * z) /
                PRECISE_UNIT +
                M2) * z) /
                PRECISE_UNIT +
                M1) * z) /
            PRECISE_UNIT +
            M0;
    }

    /**
     * @dev Converts an integer number of seconds to a fractional number of years.
     */
    function annualise(uint secs) internal pure returns (uint yearFraction) {
        return secs.divideDecimalRoundPrecise(SECONDS_PER_YEAR);
    }
}
