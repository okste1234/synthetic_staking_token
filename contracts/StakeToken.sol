// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IERC20.sol";

contract Staking {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    address public owner;
    uint public duration;
    uint public finishAt;
    uint public updateAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;
    uint public totalSupply;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updateAt = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    function setRewardDuration(uint _duration) external {
        require(finishAt < block.timestamp, "Reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmout(uint _amount) external updateReward(msg.sender) {
        if (block.timestamp > finishAt) {
            rewardRate;
        } else {
            uint remainingReward = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingReward + _amount) / duration;
        }
        require(rewardRate > 0, "Reward rate = 0");
        require(
            rewardRate * duration <= rewardToken.balanceOf(address(this)),
            "Reward amount > balance"
        );
        finishAt = block.timestamp + duration;
        updateAt = block.timestamp;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] = balanceOf[msg.sender] + _amount;
        totalSupply = totalSupply + _amount;
    }

    function min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updateAt) * 1e18) /
            totalSupply;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] = balanceOf[msg.sender] - _amount;
        totalSupply = totalSupply - _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint) {
        return
            (balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) /
            1e18 +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }
}
