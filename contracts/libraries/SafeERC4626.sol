// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "../interfaces/external/token/IERC4626.sol";
import "./SafeERC20.sol";

library SafeERC4626 {
    using SafeERC20 for address;

    error SafeDepositFailed();
    error SafeMintFailed();
    error SafeRedeemFailed();
    error SafeWithdrawFailed();

    function safeDeposit(
        address vault,
        address recipient,
        uint256 value,
        uint256 minSharesOut
    ) internal returns (uint256 sharesOut) {
        if (
            (sharesOut = IERC4626(vault).deposit(value, recipient)) <
            minSharesOut
        ) revert SafeDepositFailed();
    }

    function safeMint(
        address vault,
        address recipient,
        uint256 value,
        uint256 maxAmountIn
    ) internal returns (uint256 amountIn) {
        if ((amountIn = IERC4626(vault).mint(value, recipient)) > maxAmountIn)
            revert SafeMintFailed();
    }

    function safeWithdraw(
        address vault,
        address recipient,
        uint256 value,
        uint256 maxSharesOut
    ) internal returns (uint256 sharesOut) {
        if (
            (sharesOut = IERC4626(vault).withdraw(
                value,
                recipient,
                msg.sender
            )) > maxSharesOut
        ) revert SafeWithdrawFailed();
    }

    function safeRedeem(
        address vault,
        address recipient,
        uint256 value,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        if (
            (amountOut = IERC4626(vault).redeem(value, recipient, msg.sender)) <
            minAmountOut
        ) revert SafeRedeemFailed();
    }

    function depositMax(
        address vault,
        address recipient,
        uint256 minSharesOut
    ) internal returns (uint256 sharesOut) {
        address token = asset(vault);
        uint256 balance = token.getBalance(msg.sender);
        uint256 maxDeposit = IERC4626(vault).maxDeposit(recipient);
        uint256 value = maxDeposit < balance ? maxDeposit : balance;
        token.safeTransferFrom(msg.sender, address(this), value);

        return safeDeposit(vault, recipient, value, minSharesOut);
    }

    function redeemMax(
        address vault,
        address recipient,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        uint256 balance = vault.getBalance(msg.sender);
        uint256 maxRedeem = IERC4626(vault).maxRedeem(msg.sender);
        uint256 value = maxRedeem < balance ? maxRedeem : balance;

        return safeRedeem(vault, recipient, value, minAmountOut);
    }

    function asset(address vault) internal view returns (address) {
        return IERC4626(vault).asset();
    }
}
