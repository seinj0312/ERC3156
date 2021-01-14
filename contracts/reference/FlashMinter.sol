// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/IERC3156FlashLender.sol";


/**
 * @author Alberto Cuesta Cañada
 * @dev Extension of {ERC20} that allows flash minting.
 */
contract FlashMinter is ERC20, IERC3156FlashLender {

    uint256 public fee;

    /**
     * @param fee_ The divisor that will be applied to the `amount` of a `loan`, with the result charged as a `fee`.
     */
    constructor (string memory name, string memory symbol, uint256 fee_) ERC20(name, symbol) {
        fee = fee_;
    }

    /**
     * @dev The amount of currency available to be lended.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashAmount(address token) external view override returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency. Must match the address of this contract.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 amount) external view override returns (uint256) {
        require(token == address(this), "FlashMinter: unsupported loan currency");
        return _flashFee(token, amount);
    }

    /**
     * @dev Loan `amount` tokens to `receiver`, and takes it back plus a `flashFee` after the ERC3156 callback.
     * @param receiver The contract receiving the tokens, needs to implement the `onFlashLoan(address user, uint256 amount, uint256 fee, bytes calldata)` interface.
     * @param token The loan currency. Must match the address of this contract.
     * @param amount The amount of tokens lent.
     * @param data A data parameter to be passed on to the `receiver` for any custom use.
     */
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external override {
        require(token == address(this), "FlashMinter: unsupported loan currency");
        uint256 fee = _flashFee(token, amount);
        _mint(receiver, amount);
        IERC3156FlashBorrower(receiver).onFlashLoan(msg.sender, token, amount, fee, data);
        uint256 _allowance = allowance[receiver][address(this)];
        require(_allowance >= (amount + fee), "FlashMinter: Flash loan repayment not approved");
        _approve(receiver, address(this), _allowance - (amount + fee));
        _burn(receiver, amount + fee);
    }

    /**
     * @dev The fee to be charged for a given loan. Internal function with no checks.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function _flashFee(address token, uint256 amount) internal view returns (uint256) {
        return fee == type(uint256).max ? 0 : amount / fee;
    }
}