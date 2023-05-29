// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

interface IERC4626 {
    function asset() external view returns (address);

    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function previewDeposit(uint256 assets) external view returns (uint256);

    function previewMint(uint256 shares) external view returns (uint256);

    function previewWithdraw(uint256 assets) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);

    function maxDeposit(address account) external view returns (uint256);

    function maxMint(address account) external view returns (uint256);

    function maxWithdraw(address account) external view returns (uint256);

    function maxRedeem(address account) external view returns (uint256);

    function deposit(uint256 assets, address recipient)
        external
        returns (uint256 shares);

    function mint(uint256 shares, address recipient)
        external
        returns (uint256 assets);

    function withdraw(
        uint256 assets,
        address recipient,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address recipient,
        address owner
    ) external returns (uint256 assets);

    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed caller,
        address indexed recipient,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
}
