// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeCast {
    error SafeCastFailed();

    function toUint24(int24 x) internal pure returns (uint24) {
        if (int256(x) > int256(uint256(type(uint24).max)))
            revert SafeCastFailed();
        return x >= 0 ? uint24(x) : uint24(-x);
    }

    function toUint24(uint256 x) internal pure returns (uint24 y) {
        if ((y = uint24(x)) != x) revert SafeCastFailed();
    }

    function toUint32(uint256 x) internal pure returns (uint32 y) {
        if ((y = uint32(x)) != x) revert SafeCastFailed();
    }

    function toUint112(uint256 x) internal pure returns (uint112 y) {
        if ((y = uint112(x)) != x) revert SafeCastFailed();
    }

    function toUint128(uint256 x) internal pure returns (uint128 y) {
        if ((y = uint128(x)) != x) revert SafeCastFailed();
    }

    function toUint160(uint256 x) internal pure returns (uint160 y) {
        if ((y = uint160(x)) != x) revert SafeCastFailed();
    }

    function toUint256(int256 x) internal pure returns (uint256 y) {
        if (x < 0) revert SafeCastFailed();
        y = uint256(x);
    }

    function toInt24(uint8 x) internal pure returns (int24 y) {
        if ((y = int24(toInt256(x))) != toInt256(x)) revert SafeCastFailed();
    }

    function toInt24(int256 x) internal pure returns (int24 y) {
        if ((y = int24(x)) != x) revert SafeCastFailed();
    }

    function toInt56(int256 x) internal pure returns (int56 y) {
        if ((y = int56(x)) != x) revert SafeCastFailed();
    }

    function toInt128(int256 x) internal pure returns (int128 y) {
        if ((y = int128(x)) != x) revert SafeCastFailed();
    }

    function toInt256(uint256 x) internal pure returns (int256 y) {
        if (x >= 2 ** 255) revert SafeCastFailed();
        y = int256(x);
    }
}
