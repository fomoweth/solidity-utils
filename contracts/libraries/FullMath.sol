// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library FullMath {
    enum Rounding {
        Down,
        Up,
        Zero
    }

    uint256 private constant WAD = 1e18;

    function average(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x & y) + (x ^ y) / 2;
    }

    function divRoundingUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256 z) {
        assembly {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        unchecked {
            uint256 prod0;
            uint256 prod1;

            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            if (prod1 == 0) {
                require(denominator > 0);

                assembly {
                    z := div(prod0, denominator)
                }

                return z;
            }

            require(denominator > prod1);

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
            }

            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = (0 - denominator) & denominator;

            assembly {
                denominator := div(denominator, twos)
            }

            assembly {
                prod0 := div(prod0, twos)
            }

            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }

            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;

            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;

            z = prod0 * inverse;
        }
    }

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        unchecked {
            z = mulDiv(x, y, denominator);
            if (mulmod(x, y, denominator) > 0) {
                require(z < type(uint256).max);
                z = z + 1;
            }
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            z := 1
            let y := x

            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y)
                z := shl(8, z)
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y)
                z := shl(4, z)
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y)
                z := shl(2, z)
            }
            if iszero(lt(y, 0x4)) {
                z := shl(1, z)
            }

            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            let roundDown := div(x, z)

            if lt(roundDown, z) {
                z := roundDown
            }
        }
    }

    function sqrt(
        uint256 x,
        Rounding rounding
    ) internal pure returns (uint256 z) {
        unchecked {
            uint256 y = sqrt(x);
            z = y + (rounding == Rounding.Up && y * y < x ? 1 : 0);
        }
    }

    function wadDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mulDiv(x, WAD, y);
    }

    function wadMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mulDiv(x, y, WAD);
    }
}
