// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BytesUtils {
    function toBytes(address data) internal pure returns (bytes memory result) {
        result = new bytes(32);
        assembly {
            mstore(add(result, 32), data)
        }
    }

    function toBytes(uint256 data) internal pure returns (bytes memory result) {
        result = new bytes(32);
        assembly {
            mstore(add(result, 32), data)
        }
    }

    function toAddress(
        bytes memory data,
        uint256 offset
    ) internal pure returns (address result) {
        assembly {
            result := mload(add(data, offset))
        }
    }

    function toUint256(
        bytes memory data,
        uint256 offset
    ) internal pure returns (uint256 result) {
        assembly {
            result := mload(add(data, offset))
        }
    }

    function arrayifyAddress(
        bytes memory data
    ) internal pure returns (address[] memory result) {
        uint256 length = data.length / 32;
        result = new address[](length);

        for (uint256 i; i < length; ) {
            result[i] = toAddress(data, i * 32 + 32);

            unchecked {
                i = i + 1;
            }
        }
    }

    function arrayifyUint256(
        bytes memory data
    ) internal pure returns (uint256[] memory result) {
        uint256 length = data.length / 32;
        result = new uint256[](length);

        for (uint256 i; i < length; ) {
            result[i] = toUint256(data, i * 32 + 32);

            unchecked {
                i = i + 1;
            }
        }
    }
}
