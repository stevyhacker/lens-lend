//SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title LensLend
/// @notice Lend USDC against Lens profile NFTs
contract LensLend is Ownable {

    struct LensBorrower {
        uint256 profileId;
        uint256 reputation;
        uint256 debt;
        uint256 lastUpdated;
    }

    struct UsdcLender {
        address lender;
        uint256 suppliedBalance;
        uint256 lastUpdated;
    }

    mapping(uint256 profileId => LensBorrower borrower) public lensBorrowers;
    mapping(address account => UsdcLender lender) public lenders;

    uint256 public yearlyBorrowInterestRate = 1e17; // 10% per year
    uint256 public yearlySupplyInterestRate = 8e16; // 8% per year

    IERC20 public immutable usdc;
    IERC721 public immutable lensProfileCollection;
    AggregatorV3Interface internal nftFloorPriceFeed;

    constructor(address _usdcAddress, address _lensProfileCollection, address _nftFloorPriceFeed) Ownable(msg.sender) {
        usdc = IERC20(_usdcAddress);
        lensProfileCollection = IERC721(_lensProfileCollection);
        nftFloorPriceFeed = AggregatorV3Interface(_nftFloorPriceFeed);
    }

    /// @notice Adds a Lens profile to the lending pool
    function addBorrower(uint256 _profileId) external {
        require(lensProfileCollection.ownerOf(_profileId) == msg.sender, "Only the owner can add a Lens profile");
        require(lensBorrowers[_profileId].profileId == 0, "Lens profile already added");

        LensBorrower memory newBorrower;
        newBorrower.profileId = _profileId;
        newBorrower.reputation = getReputation(_profileId);
        lensBorrowers[_profileId] = newBorrower;

        lensProfileCollection.transferFrom(msg.sender, address(this), _profileId);
    }

    /// @notice Removes a Lens profile from the lending pool
    function removeBorrower(uint256 _profileId) external {
        require(lensProfileCollection.ownerOf(_profileId) == msg.sender, "Only the owner can remove a Lens profile");
        require(lensBorrowers[_profileId].profileId != 0, "Lens profile not added");
        require(lensBorrowers[_profileId].debt == 0, "Lens profile has unpaid debt");

        delete lensBorrowers[_profileId];
    }

    // Function to borrow USDC against Lens profile NFT
    function borrow(uint256 _profileId, uint256 _amount) external {
        require(lensProfileCollection.ownerOf(_profileId) == msg.sender, "Only the owner can borrow");
        require(usdc.balanceOf(address(this)) >= _amount, "Insufficient USDC balance in the lending pool");

        LensBorrower storage borrower = lensBorrowers[_profileId];

        require(borrower.debt + _amount < getMaxPotentialDebt(_profileId), "Lens profile already borrowed the maximum amount");

        borrower.debt += _amount;
        lensBorrowers[_profileId] = borrower;
        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Repays borrowed USDC debt of a lens profile borrower
    function repayDebt(uint256 _profileId, uint256 _amount) external {
        LensBorrower storage borrower = lensBorrowers[_profileId];
        require(borrower.debt >= _amount, "Exceeds borrowed balance");

        updateDebt(_profileId);

        borrower.debt -= _amount;
        usdc.transfer(msg.sender, _amount);
    }

    /// @notice Calculate the reputation of a Lens profile holder
    function getReputation(uint256 _tokenId) public view returns (uint256) {
        //todo: calculate reputation using lens protocol or phi land score or gitcoin passport

        return lensBorrowers[_tokenId].reputation;
    }

    /// @notice Function to get the max potential amount of debt a Lens profile can borrow
    function getMaxPotentialDebt(uint256 _profileId) public view returns (uint256) {
        uint256 currentDebt = lensBorrowers[_profileId].debt;
        uint256 maxAmount = getReputation(_profileId) * uint256(getLatestFloorPrice());

        return maxAmount - currentDebt;
    }

    /// @notice Lenders can supply USDC to the lending pool
    function supply(uint256 _amount) external {
        require(usdc.balanceOf(msg.sender) >= _amount, "Insufficient USDC balance");

        UsdcLender memory newLender;
        newLender.lender = msg.sender;
        newLender.suppliedBalance += _amount;
        lenders[msg.sender] = newLender;

        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Lenders can withdraw their USDC from the lending pool
    function withdraw(uint256 _amount) external {
        require(lenders[msg.sender].suppliedBalance >= _amount, "Insufficient supplied balance");

        UsdcLender storage lender = lenders[msg.sender];

        updateSuppliedBalance(msg.sender);

        lender.suppliedBalance -= _amount;
        lenders[msg.sender] = lender;

        usdc.transfer(msg.sender, _amount);
    }

    /// @notice Update debt of the borrowers with the current interest rate
    /// @dev This function can be called every 24h
    function updateDebt(uint256 _profileId) public {
        LensBorrower storage borrower = lensBorrowers[_profileId];

        uint256 timeSinceLastUpdate = block.timestamp - borrower.lastUpdated;
        require(timeSinceLastUpdate < 24 hours, "Cannot update debt more than once per day");

        uint256 currentDebt = borrower.debt;
        uint256 interestRate = yearlyBorrowInterestRate * (timeSinceLastUpdate / 365 days);
        uint256 accruedInterest = currentDebt * interestRate;

        require(usdc.balanceOf(address(this)) >= accruedInterest, "Insufficient USDC balance in the lending pool");
        borrower.lastUpdated = block.timestamp;
        borrower.debt += accruedInterest;
    }

    /// @notice Updates the interest for the USDC lenders
    /// @dev This function can be called every 24h
    function updateSuppliedBalance(address _lender) public {
        UsdcLender storage lender = lenders[_lender];

        uint256 timeSinceLastUpdate = block.timestamp - lender.lastUpdated;
        require(timeSinceLastUpdate < 24 hours, "Cannot update debt more than once per day");

        uint256 currentBalance = lender.suppliedBalance;
        uint256 interestRate = yearlySupplyInterestRate * (timeSinceLastUpdate / 365 days);
        uint256 accruedReward = currentBalance * interestRate;

        require(usdc.balanceOf(address(this)) >= accruedReward, "Insufficient USDC balance in the lending pool");
        lender.lastUpdated = block.timestamp;
        lender.suppliedBalance += accruedReward;
    }

    /// @notice Returns the latest Lens Profile NFT collection floor price
    function getLatestFloorPrice() public view returns (int) {
        (
        /* uint80 roundID */,
            int floorPrice,
        /* uint startedAt */,
        /* uint timeStamp */,
        /* uint80 answeredInRound */
        ) = nftFloorPriceFeed.latestRoundData();
        return floorPrice;
    }

    /// @notice Owner can claim the profit from the borrowers
    function claimProfit() external onlyOwner {
        //todo: calculate the profit from the borrowers and claim it
    }

    /// @dev Liquidate a Lens profile borrower if their debt is too high
    function liquidate(uint256 _profileId) external {
        LensBorrower storage borrower = lensBorrowers[_profileId];
        require(borrower.debt > 0, "Lens profile has no debt");

        //todo: take their NFT and sell it on the market to repay the debt

    }

}
