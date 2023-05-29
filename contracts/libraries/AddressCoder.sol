// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BytesLib.sol";

library AddressCoder {
    uint256 internal constant ADDR_SIZE = 20;

    function encodeArray(address[] memory targets)
        internal
        pure
        returns (bytes memory encoded)
    {
        uint256 length = targets.length;
        uint256 i;

        while (i < length) {
            encoded = abi.encodePacked(encoded, targets[i]);

            unchecked {
                i = i + 1;
            }
        }
    }

    function decodeArray(bytes memory data)
        internal
        pure
        returns (address[] memory result)
    {
        uint256 length = count(data);
        uint256 i;

        result = new address[](length);

        while (i < length) {
            result[i] = BytesLib.toAddress(data, 0);
            data = skip(data);

            unchecked {
                i = i + 1;
            }
        }
    }

    function count(bytes memory data) internal pure returns (uint256) {
        return data.length / ADDR_SIZE;
    }

    function skip(bytes memory data) internal pure returns (bytes memory) {
        return BytesLib.slice(data, ADDR_SIZE, data.length - ADDR_SIZE);
    }
}
