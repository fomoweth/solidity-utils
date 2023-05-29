// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/token/IERC20.sol";
import "../interfaces/external/token/IERC20Permit.sol";
import "../interfaces/external/Uniswap/IPermit2.sol";
import "../libraries/SafeERC20.sol";

abstract contract SelfPermit {
    using SafeERC20 for address;

    function selfPermit(
        address token,
        bytes calldata signature
    ) public payable {
        token.safePermit(signature);
    }

    function selfPermit2(address token) public payable {
        //
    }

    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
    }

    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (IERC20(token).allowance(msg.sender, address(this)) < value)
            selfPermit(token, value, deadline, v, r, s);
    }

    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        IERC20PermitAllowed(token).permit(
            msg.sender,
            address(this),
            nonce,
            expiry,
            true,
            v,
            r,
            s
        );
    }

    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (
            IERC20(token).allowance(msg.sender, address(this)) <
            type(uint256).max
        ) selfPermitAllowed(token, nonce, expiry, v, r, s);
    }

    function nonces(
        address token,
        address owner
    ) internal view returns (uint256 value) {
        if (token.isNative()) return type(uint256).max;

        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x7ecebe00)
            mstore(add(ptr, 0x4), owner)

            if iszero(staticcall(gas(), token, ptr, 0x44, 0x0, 0x20)) {
                revert(0, 0)
            }

            value := mload(0)
        }
    }

    // function _safePermit(address token, bytes calldata permit)
    //     private
    //     returns (bool success)
    // {
    //     if (permit.length == 32 * 7) {
    //         // ERC20-Permit
    //         return _call(token, 0xd505accf, permit);
    //     } else if (permit.length == 32 * 8) {
    //         // DAI-Like-Permit
    //         return _call(token, 0x8fcbaf0c, permit);
    //     } else {
    //         revert InvalidPermitLength();
    //     }
    // }

    // function safePermit(address token, bytes calldata permit) internal {
    //     if (!_safePermit(token, permit)) revert SafePermitFailed();
    // }

    // function _call(
    //     address token,
    //     bytes4 selector,
    //     bytes calldata data
    // ) private returns (bool success) {
    //     assembly {
    //         let len := add(4, data.length)
    //         let ptr := mload(0x40)

    //         mstore(ptr, selector)
    //         calldatacopy(add(ptr, 0x04), data.offset, data.length)

    //         success := call(gas(), token, 0, ptr, len, 0x0, 0x20)

    //         if success {
    //             switch returndatasize()
    //             case 0 {
    //                 success := gt(extcodesize(token), 0)
    //             }
    //             default {
    //                 success := and(gt(returndatasize(), 31), eq(mload(0), 1))
    //             }
    //         }
    //     }
    // }
}
