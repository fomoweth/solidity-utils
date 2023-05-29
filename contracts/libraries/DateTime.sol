// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library DateTime {
    uint64 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint64 constant SECONDS_PER_HOUR = 60 * 60;
    uint64 constant SECONDS_PER_MINUTE = 60;
    int64 constant OFFSET19700101 = 2440588;

    function getNextExpiry(
        uint256 currentExpiry
    ) internal view returns (uint256) {
        // uninitialized state
        if (currentExpiry == 0) {
            return getNextFriday(block.timestamp);
        }

        // After options expiry if no options are written for >1 week
        // We need to give the ability continue writing options
        if (block.timestamp > currentExpiry + 7 days) {
            return getNextFriday(block.timestamp);
        }

        return getNextFriday(currentExpiry);
    }

    function getNextFriday(uint256 timestamp) internal pure returns (uint256) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 dayOfWeek = ((timestamp / 1 days) + 4) % 7;
        uint256 nextFriday = timestamp + ((7 + 5 - dayOfWeek) % 7) * 1 days;
        uint256 friday1am = nextFriday - (nextFriday % (24 hours)) + (1 hours);

        // If the passed timestamp is day=Friday hour>8am, we simply increment it by a week to next Friday
        if (timestamp >= friday1am) {
            friday1am += 7 days;
        }
        return friday1am;
    }

    function _daysToDate(
        uint64 _days
    ) internal pure returns (uint64 year, uint64 month, uint64 day) {
        int64 __days = int64(_days);

        int64 L = __days + 68569 + OFFSET19700101;
        int64 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int64 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int64 _month = (80 * L) / 2447;
        int64 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint64(_year);
        month = uint64(_month);
        day = uint64(_day);
    }

    function timestampToDate(
        uint64 timestamp
    ) internal pure returns (uint64 year, uint64 month, uint64 day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }

    function getMonthString(
        uint64 month
    )
        internal
        pure
        returns (string memory shortString, string memory longString)
    {
        if (month == 1) {
            return ("JAN", "January");
        } else if (month == 2) {
            return ("FEB", "February");
        } else if (month == 3) {
            return ("MAR", "March");
        } else if (month == 4) {
            return ("APR", "April");
        } else if (month == 5) {
            return ("MAY", "May");
        } else if (month == 6) {
            return ("JUN", "June");
        } else if (month == 7) {
            return ("JUL", "July");
        } else if (month == 8) {
            return ("AUG", "August");
        } else if (month == 9) {
            return ("SEP", "September");
        } else if (month == 10) {
            return ("OCT", "October");
        } else if (month == 11) {
            return ("NOV", "November");
        } else {
            return ("DEC", "December");
        }
    }

    function getHour(uint64 timestamp) internal pure returns (uint64 hour) {
        uint64 secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }

    function getMinute(uint64 timestamp) internal pure returns (uint64 minute) {
        uint64 secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }

    function getSecond(uint64 timestamp) internal pure returns (uint64 second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }
}
