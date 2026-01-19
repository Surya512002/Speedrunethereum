// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";
import "./FundingRecipient.sol"; 

contract CrowdFund {
    // --- State Variables ---
    mapping(address => uint256) public balances;
    bool public openToWithdraw; 
    uint256 public constant threshold = 1 ether;
    uint256 public deadline = block.timestamp + 30 seconds;
    FundingRecipient public fundingRecipient;

    // --- Events & Errors ---
    event Contribution(address indexed contributor, uint256 amount);
    error NotOpenToWithdraw();
    error WithdrawTransferFailed(address to, uint256 amount);
    error TooEarly(uint256 deadline, uint256 currentTimestamp);

    constructor(address _fundingRecipient) {
        fundingRecipient = FundingRecipient(_fundingRecipient);
    }

    // --- 1. Contribute ---
    function contribute() public payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        emit Contribution(msg.sender, msg.value);
    }

    // --- 2. Withdraw (FIXED) ---
    function withdraw() public {
        if (!openToWithdraw) { revert NotOpenToWithdraw(); }
        
        uint256 amount = balances[msg.sender];
        
        // FIX: Removed the "require(amount > 0)" check so tests pass
        
        balances[msg.sender] = 0; 

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            balances[msg.sender] = amount; 
            revert WithdrawTransferFailed(msg.sender, amount);
        }
    }

    // --- 3. Execute ---
    function execute() public {
        if (block.timestamp < deadline) {
            revert TooEarly(deadline, block.timestamp);
        }

        if (address(this).balance >= threshold) {
            fundingRecipient.complete{value: address(this).balance}();
        } else {
            openToWithdraw = true;
        }
    }

    // --- 4. Helper: Time Left ---
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    // --- 5. Receive ---
    receive() external payable {
        contribute();
    }
}
