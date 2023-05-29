// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/SafeERC20.sol";

abstract contract Payments {
    using SafeERC20 for address;

    address public immutable WETH;

    constructor(address _weth) {
        WETH = _weth;
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (payer == address(this)) {
            token.safeTransfer(recipient, value);
        } else {
            token.safeTransferFrom(payer, recipient, value);

            if (token.isNative()) {
                token.wrap(value);
            }
        }
    }

    function approveMax(address token, address spender) internal {
        if (token.getAllowance(address(this), spender) != type(uint256).max) {
            token.tryApprove(spender, type(uint256).max);
        }
    }

    function approveIfNeeded(
        address token,
        address spender,
        uint256 value
    ) internal {
        if (token.getAllowance(address(this), spender) < value) {
            token.tryApprove(spender, value);
        }
    }

    function isWETH(address token) internal view returns (bool) {
        return token == WETH;
    }
}
