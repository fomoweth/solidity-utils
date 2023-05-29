// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AddressArray.sol";

library AddressSet {
    using AddressArray for AddressArray.Data;

    struct Data {
        AddressArray.Data items;
        mapping(address => uint256) lookup;
    }

    function length(Data storage self) internal view returns (uint256) {
        return self.items.length();
    }

    function at(
        Data storage self,
        uint256 index
    ) internal view returns (address) {
        return self.items.at(index);
    }

    function contains(
        Data storage self,
        address item
    ) internal view returns (bool) {
        return self.lookup[item] != 0;
    }

    function add(Data storage self, address item) internal returns (bool) {
        if (self.lookup[item] > 0) return false;

        self.lookup[item] = self.items.push(item);
        return true;
    }

    function remove(Data storage self, address item) internal returns (bool) {
        uint256 index = self.lookup[item];
        if (index == 0) return false;

        if (index < self.items.length()) {
            unchecked {
                address lastItem = self.items.at(self.items.length() - 1);
                self.items.set(index - 1, lastItem);
                self.lookup[lastItem] = index;
            }
        }

        self.items.pop();
        delete self.lookup[item];

        return true;
    }
}
