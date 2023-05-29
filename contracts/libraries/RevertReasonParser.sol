// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StringUtil.sol";

library RevertReasonParser {
    using StringUtil for bytes;
    using StringUtil for uint256;

    error InvalidRevertReason();

    bytes4 private constant ERROR_SELECTOR = bytes4(keccak256("Error(string)"));
    bytes4 private constant PANIC_SELECTOR =
        bytes4(keccak256("Panic(uint256)"));

    function parse(bytes memory data) internal pure returns (string memory) {
        return parse(data, "");
    }

    function parse(
        bytes memory data,
        string memory prefix
    ) internal pure returns (string memory) {
        // https://solidity.readthedocs.io/en/latest/control-structures.html#revert
        // We assume that revert reason is abi-encoded as Error(string)
        bytes4 selector;
        if (data.length >= 4) {
            assembly {
                selector := mload(add(data, 0x20))
            }
        }

        // 68 = 4-byte selector + 32 bytes offset + 32 bytes length
        if (selector == ERROR_SELECTOR && data.length >= 68) {
            string memory reason;
            assembly {
                // 68 = 32 bytes data length + 4-byte selector + 32 bytes offset
                reason := add(data, 68)
            }
            /*
                revert reason is padded up to 32 bytes with ABI encoder: Error(string)
                also sometimes there is extra 32 bytes of zeros padded in the end:
                https://github.com/ethereum/solidity/issues/10170
                because of that we can't check for equality and instead check
                that string length + extra 68 bytes is equal or greater than overall data length
            */
            if (data.length >= 68 + bytes(reason).length) {
                return string.concat(prefix, "Error(", reason, ")");
            }
        }
        // 36 = 4-byte selector + 32 bytes integer
        else if (selector == PANIC_SELECTOR && data.length == 36) {
            uint256 code;
            assembly {
                // 36 = 32 bytes data length + 4-byte selector
                code := mload(add(data, 36))
            }
            return string.concat(prefix, "Panic(", code.toHex(), ")");
        }
        return string.concat(prefix, "Unknown(", data.toHex(), ")");
    }

    function reRevert() internal pure {
        // bubble up revert reason from latest external call
        assembly {
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, returndatasize())
            revert(ptr, returndatasize())
        }
    }
}
