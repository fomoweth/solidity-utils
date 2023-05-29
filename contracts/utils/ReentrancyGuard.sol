// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReentrancyGuard {
    error ReentrancyGuardLocked();

    uint256 private constant UNLOCKED = 1;
    uint256 private constant LOCKED = 2;

    uint256 private _locker = UNLOCKED;

    modifier lock() {
        if (_locker == LOCKED) revert ReentrancyGuardLocked();
        _locker = LOCKED;
        _;
        _locker = UNLOCKED;
    }
}
