// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/RevertReasonParser.sol";

abstract contract Multicall {
    function multicall(
        bytes[] calldata payloads
    ) public payable returns (bytes[] memory returnData) {
        uint256 length = payloads.length;
        returnData = new bytes[](length);

        for (uint256 i; i < length; ) {
            bool success;
            (success, returnData[i]) = address(this).delegatecall(payloads[i]);

            if (!success) revert(RevertReasonParser.parse(returnData[i]));

            unchecked {
                i = i + 1;
            }
        }
    }
}
