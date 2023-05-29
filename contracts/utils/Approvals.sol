// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/SafeERC20.sol";

abstract contract Approvals {
    using SafeERC20 for address;

    uint256 private constant MAX_UINT256 = type(uint256).max;

    function approveIfNeeded(
        address token,
        address spender,
        uint256 value
    ) internal {
        if (allowance(token, spender) < value) token.tryApprove(spender, value);
    }

    function approveMax(address token, address spender) internal {
        if (allowance(token, spender) != MAX_UINT256)
            token.tryApprove(spender, MAX_UINT256);
    }

    function approveZero(address token, address spender) internal {
        if (allowance(token, spender) != 0) token.safeApprove(spender, 0);
    }

    function allowance(
        address token,
        address spender
    ) internal view returns (uint256 value) {
        if (token.isNative()) return MAX_UINT256;

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0xdd62ed3e)
            mstore(add(ptr, 0x4), address())
            mstore(add(ptr, 0x24), spender)

            if iszero(staticcall(gas(), token, ptr, 0x44, 0x0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }
}
