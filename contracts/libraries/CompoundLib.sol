// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/external/Compound/IComptroller.sol";
import "../interfaces/external/Compound/ICToken.sol";
import "../interfaces/external/Compound/IInterestRateModel.sol";
import "./FullMath.sol";

library CompoundLib {
    using FullMath for uint256;

    error RateTooHigh();

    uint256 private constant MAX_BORROW_RATE = 0.0005e16;

    function computeAccruedRewards(
        IComptroller comptroller,
        address cToken,
        address account
    ) internal view returns (uint256) {
        uint256 rewardAccrued = comptroller.compAccrued(account);

        return
            rewardAccrued +
            supplyAccrued(comptroller, cToken, account) +
            borrowAccrued(comptroller, cToken, account);
    }

    function supplyAccrued(
        IComptroller comptroller,
        address cToken,
        address account
    ) internal view returns (uint256) {
        uint256 supplyIndex = _supplyIndex(comptroller, cToken);

        uint256 supplierIndex = comptroller.compSupplierIndex(cToken, account);

        if (supplierIndex == 0 && supplyIndex > 0) {
            supplierIndex = 1e36;
        }

        uint256 deltaIndex = supplyIndex > 0 ? supplyIndex - supplierIndex : 0;

        return ICERC20(cToken).balanceOf(account).wadMul(deltaIndex);
    }

    function borrowAccrued(
        IComptroller comptroller,
        address cToken,
        address account
    ) internal view returns (uint256 borrowerDelta) {
        uint256 borrowerIndex = comptroller.compBorrowerIndex(cToken, account);

        if (borrowerIndex > 0) {
            uint256 marketBorrowIndex = ICERC20(cToken).borrowIndex();

            uint256 borrowIndex = _borrowIndex(
                comptroller,
                cToken,
                marketBorrowIndex
            );

            if (borrowIndex > 0) {
                uint256 deltaIndex = borrowIndex - borrowerIndex;

                uint256 borrowerAmount = ICERC20(cToken)
                    .borrowBalanceStored(account)
                    .wadDiv(marketBorrowIndex);

                borrowerDelta = borrowerAmount.wadMul(deltaIndex);
            }
        }
    }

    function _supplyIndex(
        IComptroller comptroller,
        address cToken
    ) private view returns (uint256 index) {
        (uint256 supplyStateIndex, uint256 supplyStateTimestamp) = comptroller
            .compSupplyState(cToken);

        uint256 deltaTimestamps = block.timestamp - supplyStateTimestamp;

        uint256 supplySpeed = comptroller.compSupplySpeeds(cToken);

        if (deltaTimestamps > 0 && supplySpeed > 0) {
            uint256 supplies = ICERC20(cToken).totalSupply();
            uint256 accruedRewards = deltaTimestamps.wadMul(supplySpeed);

            uint256 ratio = supplies > 0 ? accruedRewards.wadDiv(supplies) : 0;

            index = supplyStateIndex + ratio;
        }
    }

    function _borrowIndex(
        IComptroller comptroller,
        address cToken,
        uint256 marketBorrowIndex
    ) private view returns (uint256 index) {
        (uint256 borrowStateIndex, uint256 borrowStateTimestamp) = comptroller
            .compBorrowState(cToken);

        uint256 borrowSpeed = comptroller.compBorrowSpeeds(cToken);

        uint256 deltaTimestamps = block.timestamp - borrowStateTimestamp;

        if (deltaTimestamps > 0 && borrowSpeed > 0) {
            uint256 borrows = ICERC20(cToken).totalBorrows().wadDiv(
                marketBorrowIndex
            );

            uint256 accruedRewards = deltaTimestamps.wadMul(borrowSpeed);

            uint256 ratio = borrows > 0 ? accruedRewards.wadDiv(borrows) : 0;

            index = borrowStateIndex + ratio;
        }
    }

    function convertToUnderlying(
        address cToken,
        uint256 amount
    ) internal view returns (uint256) {
        return amount.wadMul(getExchangeRate(ICERC20(cToken)));
    }

    function getExchangeRate(ICERC20 cToken) internal view returns (uint256) {
        uint256 totalSupply = cToken.totalSupply();

        if (totalSupply == 0) return cToken.initialExchangeRateMantissa();

        uint256 currentBlockNumber = block.number;
        uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();

        if (accrualBlockNumberPrior == currentBlockNumber)
            return cToken.exchangeRateStored();

        uint256 cashPrior = cToken.getCash();
        uint256 borrowsPrior = cToken.totalBorrows();
        uint256 reservesPrior = cToken.totalReserves();

        uint256 borrowRateMantissa = IInterestRateModel(
            cToken.interestRateModel()
        ).getBorrowRate(cashPrior, borrowsPrior, reservesPrior);

        if (borrowRateMantissa > MAX_BORROW_RATE) revert RateTooHigh();

        uint256 interestAccumulated = (borrowRateMantissa *
            (currentBlockNumber - accrualBlockNumberPrior)).wadMul(
                borrowsPrior
            );

        uint256 reservesDelta = cToken.reserveFactorMantissa().wadMul(
            interestAccumulated
        ) + reservesPrior;
        uint256 borrowsDelta = interestAccumulated + borrowsPrior;

        return (cashPrior + borrowsDelta - reservesDelta).wadDiv(totalSupply);
    }
}
