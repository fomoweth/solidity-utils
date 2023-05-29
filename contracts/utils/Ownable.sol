// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Ownable {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    error NotOwner();
    error NewOwnerZeroAddress();

    address private _owner;

    modifier onlyOwner() {
        _checkOwner(msg.sender);
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) private {
        if (newOwner == address(0)) revert NewOwnerZeroAddress();

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function owner() external view virtual returns (address) {
        return _owner;
    }

    function _checkOwner(address account) private view {
        if (account != _owner) revert NotOwner();
    }
}
