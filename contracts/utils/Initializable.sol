// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Initializable {
    error AlreadyInitialized();
    error NotInitializing();

    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        _isInitialized();

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    modifier onlyInitializing() {
        _isInitialzing();
        _;
    }

    function _isInitialized() private view {
        if (_initialized && !_initializing) revert AlreadyInitialized();
    }

    function _isInitialzing() private view {
        if (!_initializing) revert NotInitializing();
    }
}
