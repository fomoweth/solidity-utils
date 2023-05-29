// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/token/IERC20Metadata.sol";
import "../interfaces/external/token/IERC20Permit.sol";
import "../interfaces/external/token/IERC20PermitAllowed.sol";
import "../interfaces/external/Uniswap/IPermit2.sol";
import "./RevertReasonParser.sol";

library SafeERC20 {
    error SafeApproveFailed();
    error SafeTransferFailed();
    error SafeTransferNativeFailed();
    error SafeTransferFromFailed();
    error SafeTransferFrom2Failed();
    error SafePermitBadLength();
    error Permit2ExceededTransferableAmount();

    bytes4 private constant ALLOWANCE_SELECTOR = IERC20.allowance.selector;
    bytes4 private constant APPROVE_SELECTOR = IERC20.approve.selector;
    bytes4 private constant BALANCE_OF_SELECTOR = IERC20.balanceOf.selector;
    bytes4 private constant TRANSFER_SELECTOR = IERC20.transfer.selector;
    bytes4 private constant TRANSFER_FROM_SELECTOR =
        IERC20.transferFrom.selector;
    bytes4 private constant PERMIT_SELECTOR = IERC20Permit.permit.selector;
    bytes4 private constant PERMIT_ALLOWED_SELECTOR =
        IERC20PermitAllowed.permit.selector;
    bytes4 private constant PERMIT2_SELECTOR = IPermit2.permit.selector;
    bytes4 private constant PERMIT2_TRANSFER_FROM_SELECTOR =
        IPermit2.transferFrom.selector;
    bytes4 private constant PERMIT_LENGTH_ERROR_SELECTOR = 0x68275857;

    address private constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function safeApprove(
        address token,
        address spender,
        uint256 value
    ) internal {
        if (!_call(token, APPROVE_SELECTOR, spender, value))
            revert SafeApproveFailed();
    }

    function tryApprove(
        address token,
        address spender,
        uint256 value
    ) internal {
        if (!_call(token, APPROVE_SELECTOR, spender, value)) {
            if (
                !_call(token, APPROVE_SELECTOR, spender, 0) ||
                !_call(token, APPROVE_SELECTOR, spender, value)
            ) {
                revert SafeApproveFailed();
            }
        }
    }

    function approveMax(address token, address spender) internal {
        tryApprove(token, spender, type(uint256).max);
    }

    function safeTransfer(
        address token,
        address recipient,
        uint256 value
    ) internal {
        if (!isNative(token)) {
            if (!_call(token, TRANSFER_SELECTOR, recipient, value))
                revert SafeTransferFailed();
        } else {
            bool success;

            assembly {
                success := call(gas(), recipient, value, 0, 0, 0, 0)
            }

            if (!success) revert SafeTransferNativeFailed();
        }
    }

    function safeTransferFrom(
        address token,
        address sender,
        address recipient,
        uint256 value
    ) internal {
        if (!isNative(token)) {
            bytes4 selector = TRANSFER_FROM_SELECTOR;
            bool success;

            assembly {
                let ptr := mload(0x40)

                mstore(ptr, selector)
                mstore(add(ptr, 0x04), sender)
                mstore(add(ptr, 0x24), recipient)
                mstore(add(ptr, 0x44), value)

                success := call(gas(), token, 0, ptr, 100, 0x0, 0x20)

                if success {
                    switch returndatasize()
                    case 0 {
                        success := gt(extcodesize(token), 0)
                    }
                    default {
                        success := and(
                            gt(returndatasize(), 31),
                            eq(mload(0), 1)
                        )
                    }
                }
            }

            if (!success) revert SafeTransferFromFailed();
        }
    }

    function safeTransferFromPermit2(
        address token,
        address sender,
        address recipient,
        uint256 value
    ) internal {
        if (value > type(uint160).max)
            revert Permit2ExceededTransferableAmount();

        bytes4 selector = PERMIT2_TRANSFER_FROM_SELECTOR;
        bool success;

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), sender)
            mstore(add(ptr, 0x24), recipient)
            mstore(add(ptr, 0x44), value)
            mstore(add(ptr, 0x64), token)

            success := call(gas(), PERMIT2, 0, ptr, 0x84, 0x0, 0x0)

            if success {
                success := gt(extcodesize(PERMIT2), 0)
            }
        }

        if (!success) revert SafeTransferFrom2Failed();
    }

    function _call(
        address token,
        bytes4 selector,
        address target,
        uint256 value
    ) private returns (bool success) {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), target)
            mstore(add(ptr, 0x24), value)

            success := call(gas(), token, 0, ptr, 0x44, 0x0, 0x20)

            if success {
                switch returndatasize()
                case 0 {
                    success := gt(extcodesize(token), 0)
                }
                default {
                    success := and(gt(returndatasize(), 31), eq(mload(0), 1))
                }
            }
        }
    }

    function wrap(address weth, uint256 value) internal {
        assembly {
            if or(iszero(weth), iszero(value)) {
                revert(0, 0)
            }

            let ptr := mload(0x40)

            mstore(
                ptr,
                0xd0e30db000000000000000000000000000000000000000000000000000000000
            )

            if iszero(call(gas(), weth, value, ptr, 0x4, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function unwrap(address weth, uint256 value) internal {
        assembly {
            if or(iszero(weth), iszero(value)) {
                revert(0, 0)
            }

            let ptr := mload(0x40)

            mstore(
                ptr,
                0x2e1a7d4d00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 4), value)

            if iszero(call(gas(), weth, 0, ptr, 0x24, 0, 0)) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function safePermit(address token, bytes calldata signature) internal {
        if (!tryPermit(token, msg.sender, address(this), signature))
            RevertReasonParser.reRevert();
    }

    function safePermit(
        address token,
        address owner,
        address spender,
        bytes calldata signature
    ) internal {
        if (!tryPermit(token, owner, spender, signature))
            RevertReasonParser.reRevert();
    }

    function tryPermit(
        address token,
        bytes calldata signature
    ) internal returns (bool success) {
        return tryPermit(token, msg.sender, address(this), signature);
    }

    function tryPermit(
        address token,
        address owner,
        address spender,
        bytes calldata signature
    ) internal returns (bool success) {
        // load function selectors for different permit standards
        bytes4 permitSelector = PERMIT_SELECTOR;
        bytes4 permitAllowedSelector = PERMIT_ALLOWED_SELECTOR;
        bytes4 permit2Selector = PERMIT2_SELECTOR;

        assembly {
            let ptr := mload(0x40)

            // Switch case for different signature lengths, indicating different signature standards
            switch signature.length
            // Compact IERC20Permit
            case 100 {
                // store selector
                mstore(ptr, permitSelector)
                // store owner
                mstore(add(ptr, 0x04), owner)
                // store spender
                mstore(add(ptr, 0x24), spender)

                // Compact IERC20Permit.permit(uint256 value, uint32 deadline, uint256 r, uint256 vs)
                {
                    // stack too deep
                    // loads signature.offset 0x20..0x23
                    let deadline := shr(
                        224,
                        calldataload(add(signature.offset, 0x20))
                    )
                    // loads signature.offset 0x44..0x63
                    let vs := calldataload(add(signature.offset, 0x44))

                    // store value = copy signature.offset 0x00..0x19
                    calldatacopy(add(ptr, 0x44), signature.offset, 0x20)
                    // store deadline = deadline - 1
                    mstore(add(ptr, 0x64), sub(deadline, 1))
                    // store v = most significant bit of vs + 27 (27 or 28)
                    mstore(add(ptr, 0x84), add(27, shr(255, vs)))
                    // store r = copy signature.offset 0x24..0x43
                    calldatacopy(
                        add(ptr, 0xa4),
                        add(signature.offset, 0x24),
                        0x20
                    )
                    // store s = vs without most significant bit
                    mstore(add(ptr, 0xc4), shr(1, shl(1, vs)))
                }
                // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
            // Compact IDaiLikePermit
            case 72 {
                // store selector
                mstore(ptr, permitAllowedSelector)
                // store owner
                mstore(add(ptr, 0x04), owner)
                // store spender
                mstore(add(ptr, 0x24), spender)

                // Compact IDaiLikePermit.permit(uint32 nonce, uint32 expiry, uint256 r, uint256 vs)
                {
                    // stack too deep
                    // loads signature.offset 0x04..0x07
                    let expiry := shr(
                        224,
                        calldataload(add(signature.offset, 0x04))
                    )
                    // loads signature.offset 0x28..0x47
                    let vs := calldataload(add(signature.offset, 0x28))

                    // store nonce = copy signature.offset 0x00..0x03
                    mstore(
                        add(ptr, 0x44),
                        shr(224, calldataload(signature.offset))
                    )
                    // store expiry = expiry - 1
                    mstore(add(ptr, 0x64), sub(expiry, 1))
                    // store allowed = true
                    mstore(add(ptr, 0x84), true)
                    // store v = most significant bit of vs + 27 (27 or 28)
                    mstore(add(ptr, 0xa4), add(27, shr(255, vs)))
                    // store r = copy signature.offset 0x08..0x27
                    calldatacopy(
                        add(ptr, 0xc4),
                        add(signature.offset, 0x08),
                        0x20
                    )
                    // store s = vs without most significant bit
                    mstore(add(ptr, 0xe4), shr(1, shl(1, vs)))
                }
                // IDaiLikePermit.permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0x104, 0, 0)
            }
            // IERC20Permit
            case 224 {
                mstore(ptr, permitSelector)
                // copy signature calldata
                calldatacopy(add(ptr, 0x04), signature.offset, signature.length)
                // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0xe4, 0, 0)
            }
            // IDaiLikePermit
            case 256 {
                mstore(ptr, permitAllowedSelector)
                // copy signature calldata
                calldatacopy(add(ptr, 0x04), signature.offset, signature.length)
                // IDaiLikePermit.permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
                success := call(gas(), token, 0, ptr, 0x104, 0, 0)
            }
            // Compact IPermit2
            case 96 {
                // Compact IPermit2.permit(uint160 amount, uint32 expiration, uint32 nonce, uint32 sigDeadline, uint256 r, uint256 vs)
                // store selector
                mstore(ptr, permit2Selector)
                // store owner
                mstore(add(ptr, 0x04), owner)
                // store token
                mstore(add(ptr, 0x24), token)
                // store amount = copy signature.offset 0x00..0x13
                calldatacopy(add(ptr, 0x50), signature.offset, 0x14)
                // and(0xffffffffffff, ...) - conversion to uint48
                // store expiration = ((signature.offset 0x14..0x17 - 1) & 0xffffffffffff)
                mstore(
                    add(ptr, 0x64),
                    and(
                        0xffffffffffff,
                        sub(
                            shr(224, calldataload(add(signature.offset, 0x14))),
                            1
                        )
                    )
                )
                mstore(
                    add(ptr, 0x84),
                    shr(224, calldataload(add(signature.offset, 0x18)))
                )
                // store spender
                mstore(add(ptr, 0xa4), spender)
                // and(0xffffffffffff, ...) - conversion to uint48
                // store sigDeadline = ((signature.offset 0x1c..0x1f - 1) & 0xffffffffffff)
                mstore(
                    add(ptr, 0xc4),
                    and(
                        0xffffffffffff,
                        sub(
                            shr(224, calldataload(add(signature.offset, 0x1c))),
                            1
                        )
                    )
                )
                // store offset = 256
                mstore(add(ptr, 0xe4), 0x100)
                // store length = 64
                mstore(add(ptr, 0x104), 0x40)
                // store r = copy signature.offset 0x20..0x3f
                calldatacopy(add(ptr, 0x124), add(signature.offset, 0x20), 0x20)
                // store vs = copy signature.offset 0x40..0x5f
                calldatacopy(add(ptr, 0x144), add(signature.offset, 0x40), 0x20)
                // IPermit2.permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature)
                success := call(gas(), PERMIT2, 0, ptr, 0x164, 0, 0)
            }
            // IPermit2
            case 352 {
                mstore(ptr, permit2Selector)
                // copy signature calldata
                calldatacopy(add(ptr, 0x04), signature.offset, signature.length)
                // IPermit2.permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature)
                success := call(gas(), PERMIT2, 0, ptr, 0x164, 0, 0)
            }
            // Unknown
            default {
                mstore(ptr, PERMIT_LENGTH_ERROR_SELECTOR)
                revert(ptr, 4)
            }
        }
    }

    function getAllowance(
        address token,
        address owner,
        address spender
    ) internal view returns (uint256 value) {
        if (isNative(token)) return type(uint256).max;

        bytes4 selector = ALLOWANCE_SELECTOR;

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x4), owner)
            mstore(add(ptr, 0x24), spender)

            if iszero(staticcall(gas(), token, ptr, 0x44, 0x0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getBalance(
        address token,
        address account
    ) internal view returns (uint256 value) {
        if (isNative(token)) return account.balance;

        bytes4 selector = BALANCE_OF_SELECTOR;

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x4), account)

            if iszero(staticcall(gas(), token, ptr, 0x24, 0x0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function getDecimals(address token) internal view returns (uint8 value) {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x313ce567)

            if iszero(staticcall(gas(), token, ptr, 0x4, 0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    function isNative(address token) internal pure returns (bool) {
        return token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }
}
