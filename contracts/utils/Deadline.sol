// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Deadline {
    error Expired();

    modifier checkDeadline(uint256 deadline) {
        _checkDeadline(deadline);
        _;
    }

    function _checkDeadline(uint256 deadline) private view {
        if (_blockTimestamp() > deadline) {
            revert Expired();
        }
    }

    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
