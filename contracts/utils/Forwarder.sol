// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/RevertReasonParser.sol";

abstract contract Forwarder {
    error TargetZeroAddress();

    enum Operation {
        CALL,
        DELEGATECALL
    }

    function forward(
        Operation operation,
        address target,
        bytes memory payload,
        uint256 value
    ) internal returns (bytes memory returnData) {
        if (target == address(0)) revert TargetZeroAddress();

        bool success;

        if (operation == Operation.CALL) {
            (success, returnData) = target.call{value: value}(payload);
        } else {
            (success, returnData) = target.delegatecall(payload);
        }

        if (!success) {
            assembly {
                returnData := add(returnData, 0x04)
            }

            revert(RevertReasonParser.parse(returnData));
        }
    }

    function callStatic(
        address target,
        bytes memory payload
    ) internal view returns (bytes memory returnData) {
        if (target == address(0)) revert TargetZeroAddress();

        bool success;
        (success, returnData) = target.staticcall(payload);

        if (!success) {
            assembly {
                returnData := add(returnData, 0x04)
            }

            revert(RevertReasonParser.parse(returnData));
        }
    }
}
