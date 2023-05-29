// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
    function isComptroller() external view returns (bool);

    function checkMembership(
        address account,
        address cToken
    ) external view returns (bool);

    function closeFactorMantissa() external view returns (uint256);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function oracle() external view returns (address);

    function getAllMarkets() external view returns (address[] memory);

    function markets(
        address cToken
    ) external view returns (bool, uint256, bool);

    function getAssetsIn(
        address account
    ) external view returns (address[] memory);

    function getAccountLiquidity(
        address account
    ) external view returns (uint256, uint256, uint256);

    function getHypotheticalAccountLiquidity(
        address account,
        address cTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256, uint256);

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint256 repayAmount
    ) external view returns (uint256, uint256);

    function borrowCaps(address cToken) external view returns (uint256);

    function getCompAddress() external view returns (address);

    function compRate() external view returns (uint256);

    function compSpeeds(address cToken) external view returns (uint256);

    function compSupplySpeeds(address cToken) external view returns (uint256);

    function compBorrowSpeeds(address cToken) external view returns (uint256);

    function compSupplyState(
        address cToken
    ) external view returns (uint224, uint32);

    function compBorrowState(
        address cToken
    ) external view returns (uint224, uint32);

    function compSupplierIndex(
        address cToken,
        address supplier
    ) external view returns (uint256);

    function compBorrowerIndex(
        address cToken,
        address borrower
    ) external view returns (uint256);

    function compAccrued(address holder) external view returns (uint256);

    function claimComp(address holder) external;

    function enterMarkets(
        address[] calldata cTokens
    ) external returns (uint256[] memory);

    function exitMarket(address cToken) external returns (uint256);
}
