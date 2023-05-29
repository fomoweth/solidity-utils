// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/IERC20Metadata.sol";

interface ICERC20 is IERC20Metadata {
    function isCToken() external view returns (bool);

    function comptroller() external view returns (address);

    function interestRateModel() external view returns (address);

    function underlying() external view returns (address);

    function accrualBlockNumber() external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function borrowRateMaxMantissa() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function getCash() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function totalReserves() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function initialExchangeRateMantissa() external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOfUnderlying(address account) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(
        address account
    ) external view returns (uint256);

    function getAccountSnapshot(
        address account
    ) external view returns (uint256, uint256, uint256, uint256);

    function mint(uint256 amount) external returns (uint256);

    function redeem(uint256 amount) external returns (uint256);

    function redeemUnderlying(uint256 amount) external returns (uint256);

    function borrow(uint256 amount) external returns (uint256);

    function repayBorrow(uint256 amount) external returns (uint256);

    function repayBorrowBehalf(
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 amount,
        address collateral
    ) external returns (uint256);
}

interface ICETH is ICERC20 {
    function mint() external payable;

    function repayBorrow() external payable;

    function repayBorrowBehalf(address borrower) external payable;

    function liquidateBorrow(
        address _borrower,
        address _collateral
    ) external payable;
}
