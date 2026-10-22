// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title TimedEscrow
/// @notice Holds one ETH payment until the buyer releases it or the refund deadline passes.
/// @dev Deploy one instance per transaction. This is an educational reference, not an audited product.
contract TimedEscrow {
    enum Status {
        AwaitingDeposit,
        Funded,
        Released,
        Refunded
    }

    address public immutable buyer;
    address public immutable seller;
    uint256 public immutable refundDeadline;

    uint256 public depositAmount;
    Status public status;

    error ZeroAddress();
    error BuyerCannotBeSeller();
    error InvalidDuration();
    error Unauthorized();
    error InvalidStatus();
    error EmptyDeposit();
    error DeadlineNotReached();
    error TransferFailed();

    event Deposited(address indexed buyer, uint256 amount);
    event PaymentReleased(address indexed buyer, address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert Unauthorized();
        _;
    }

    modifier inStatus(Status expected) {
        if (status != expected) revert InvalidStatus();
        _;
    }

    /// @param sellerAddress Wallet that receives the payment when the buyer approves release.
    /// @param refundWindow Seconds after deployment before the buyer can reclaim the deposit.
    constructor(address sellerAddress, uint256 refundWindow) {
        if (sellerAddress == address(0)) revert ZeroAddress();
        if (sellerAddress == msg.sender) revert BuyerCannotBeSeller();
        if (refundWindow == 0) revert InvalidDuration();

        buyer = msg.sender;
        seller = sellerAddress;
        refundDeadline = block.timestamp + refundWindow;
        status = Status.AwaitingDeposit;
    }

    /// @notice Lock ETH in the contract. Only one deposit is accepted.
    function deposit() external payable onlyBuyer inStatus(Status.AwaitingDeposit) {
        if (msg.value == 0) revert EmptyDeposit();

        depositAmount = msg.value;
        status = Status.Funded;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Approve payment to the seller before or after the deadline.
    function release() external onlyBuyer inStatus(Status.Funded) {
        uint256 amount = depositAmount;
        status = Status.Released;
        depositAmount = 0;

        (bool sent, ) = payable(seller).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit PaymentReleased(buyer, seller, amount);
    }

    /// @notice Return the deposit to the buyer after the refund deadline.
    function refund() external onlyBuyer inStatus(Status.Funded) {
        if (block.timestamp < refundDeadline) revert DeadlineNotReached();

        uint256 amount = depositAmount;
        status = Status.Refunded;
        depositAmount = 0;

        (bool sent, ) = payable(buyer).call{value: amount}("");
        if (!sent) revert TransferFailed();
        emit Refunded(buyer, amount);
    }
}
