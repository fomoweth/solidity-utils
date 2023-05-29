// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressArray {
    error EmptyArray();
    error OutOfBounds();
    error Underflow();

    struct Data {
        mapping(uint256 => uint256) _raw;
    }

    function length(Data storage self) internal view returns (uint256) {
        return self._raw[0] >> 160;
    }

    function at(Data storage self, uint256 i) internal view returns (address) {
        return address(uint160(self._raw[i]));
    }

    function get(
        Data storage self
    ) internal view returns (address[] memory result) {
        uint256 lengthAndFirst = self._raw[0];
        result = new address[](lengthAndFirst >> 160);

        _get(self, result, lengthAndFirst);
    }

    function get(
        Data storage self,
        address[] memory output
    ) internal view returns (address[] memory) {
        return _get(self, output, self._raw[0]);
    }

    function _get(
        Data storage self,
        address[] memory output,
        uint256 lengthAndFirst
    ) private view returns (address[] memory) {
        uint256 len = lengthAndFirst >> 160;
        if (len > output.length) revert Underflow();

        if (len > 0) {
            output[0] = address(uint160(lengthAndFirst));

            unchecked {
                for (uint256 i = 1; i < len; ) {
                    output[i] = address(uint160(self._raw[i]));

                    i = i + 1;
                }
            }
        }
        return output;
    }

    function push(
        Data storage self,
        address account
    ) internal returns (uint256) {
        unchecked {
            uint256 lengthAndFirst = self._raw[0];
            uint256 len = lengthAndFirst >> 160;

            if (len == 0) {
                self._raw[0] = (1 << 160) + uint160(account);
            } else {
                self._raw[0] = lengthAndFirst + (1 << 160);
                self._raw[len] = uint160(account);
            }

            return len + 1;
        }
    }

    function pop(Data storage self) internal {
        unchecked {
            uint256 lengthAndFirst = self._raw[0];
            uint256 len = lengthAndFirst >> 160;

            if (len == 0) revert EmptyArray();

            self._raw[len - 1] = 0;

            if (len > 1) {
                self._raw[0] = lengthAndFirst - (1 << 160);
            }
        }
    }

    function set(Data storage self, uint256 index, address target) internal {
        uint256 len = length(self);
        if (index >= len) revert OutOfBounds();

        if (index == 0) {
            self._raw[0] = (len << 160) | uint160(target);
        } else {
            self._raw[index] = uint160(target);
        }
    }
}
