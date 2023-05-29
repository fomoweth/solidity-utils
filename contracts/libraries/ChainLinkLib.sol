// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/ChainLink/IAggregator.sol";

library ChainLinkLib {
    error RoundNotCompleted();
    error InvalidRoundId();

    uint256 internal constant BASE = 8;
    uint256 internal constant PHASE_OFFSET = 64;

    function validateRoundId(
        IAggregator feed,
        uint80 roundId,
        uint256 timestamp
    ) internal view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.getRoundData(roundId);

        if (answer < 0 && updatedAt <= 0) revert RoundNotCompleted();

        if (timestamp > updatedAt) revert InvalidRoundId();

        if (
            roundId >
            uint80((uint256(roundId >> PHASE_OFFSET) << PHASE_OFFSET) | 1)
        ) {
            (bool success, bytes memory data) = address(feed).staticcall(
                abi.encodeWithSelector(
                    IAggregator.getRoundData.selector,
                    roundId - 1
                )
            );

            if (success) {
                (, int256 lastAnswer, , uint256 lastUpdatedAt, ) = abi.decode(
                    data,
                    (uint80, int256, uint256, uint256, uint80)
                );

                if (lastAnswer >= 0 || timestamp < lastUpdatedAt)
                    revert InvalidRoundId();
            }
        }
        return uint256(answer);
    }

    function getRoundData(
        IAggregator feed,
        uint256 timestamp
    ) internal view returns (uint80, uint256) {
        (uint80 maxRoundId, int256 answer, , uint256 maxUpdatedAt, ) = feed
            .latestRoundData();

        if (timestamp > maxUpdatedAt) revert RoundNotCompleted();

        uint80 minRoundId = uint80(
            (uint256(maxRoundId >> PHASE_OFFSET) << PHASE_OFFSET) | 1
        );

        if (minRoundId == maxRoundId) {
            if (answer < 0) revert RoundNotCompleted();

            return (maxRoundId, uint256(answer));
        }

        uint256 minUpdatedAt;
        (, answer, , minUpdatedAt, ) = feed.getRoundData(minRoundId);

        (uint80 midRoundId, uint256 midUpdatedAt) = (minRoundId, minUpdatedAt);
        uint256 _maxRoundId = maxRoundId;

        if (minUpdatedAt >= timestamp && answer >= 0 && minUpdatedAt > 0) {
            return (minRoundId, uint256(answer));
        } else if (minUpdatedAt < timestamp) {
            while (minRoundId <= maxRoundId) {
                midRoundId = uint80(
                    (uint256(minRoundId) + uint256(maxRoundId)) / 2
                );
                (, answer, , midUpdatedAt, ) = feed.getRoundData(midRoundId);
                if (midUpdatedAt < timestamp) {
                    minRoundId = midRoundId + 1;
                } else if (midUpdatedAt > timestamp) {
                    maxRoundId = midRoundId - 1;
                } else if (answer < 0 || midUpdatedAt == 0) {
                    break;
                } else {
                    return (midRoundId, uint256(answer));
                }
            }
        }

        while (midUpdatedAt < timestamp || answer < 0 || midUpdatedAt == 0) {
            if (midRoundId >= _maxRoundId) revert InvalidRoundId();
            midRoundId++;
            (, answer, , midUpdatedAt, ) = feed.getRoundData(midRoundId);
        }
        return (midRoundId, uint256(answer));
    }

    function scaleToBase(
        uint256 price,
        uint8 unit
    ) internal pure returns (uint256) {
        if (unit > BASE) {
            price = price / (10 ** (uint256(unit) - (BASE)));
        } else if (unit < BASE) {
            price = price * (10 ** (BASE - (unit)));
        }

        return price;
    }
}
