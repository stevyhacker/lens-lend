//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LensLend {

    struct LensBorrower {
        uint256 lensProfileTokenId;
        uint256 reputation;
        uint256 debt;
    }

    struct UsdcLender {
        address lender;
        uint256 suppliedBalance;
    }

    mapping(uint256 profileId => LensBorrower) private lensBorrowers;
    mapping(address user => UsdcLender) private lenders;

    // Constants
    IERC20 public immutable usdc; // USDC on Polygon 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
    IERC721 public immutable lensProfileCollection; // Lens profile collection on Polygon 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d

    constructor(address _usdcAddress, address _lensProfileCollection) {
        usdc = IERC20(_usdcAddress);
        lensProfileCollection = IERC721(_lensProfileCollection);
    }

    function addNewBorrower(uint256 _lensProfileTokenId) external {
        LensBorrower memory newBorrower;

        newBorrower.reputation = getReputation(_lensProfileTokenId);
        newBorrower.lensProfileTokenId = _lensProfileTokenId;

        lensBorrowers[_lensProfileTokenId] = newBorrower;
    }

    // Function to borrow USDC against Lens profile NFT
    function borrow(uint256 _tokenId, uint256 _amount) external {
        require(lensProfileCollection.ownerOf(_tokenId) == msg.sender, "Only the owner can borrow");
        LensBorrower storage borrower = lensBorrowers[_tokenId];

        require(borrower.debt == 0, "Lens profile already borrowed the maximum amount");
        require(usdc.balanceOf(address(this)) >= _amount, "Insufficient USDC balance in the lending pool");

        borrower.debt += _amount;
        lensBorrowers[_tokenId] = borrower;
        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev Repays borrowed USDC debt of a lens profile borrower
    function repayDebt(uint256 _tokenId, uint256 _amount) external {
        LensBorrower storage borrower = lensBorrowers[_tokenId];
        require(borrower.debt >= _amount, "Exceeds borrowed balance");
        borrower.debt -= _amount;
        usdc.transfer(msg.sender, _amount);
    }

    /// @dev Calculate the reputation of a Lens profile holder
    function getReputation(uint256 _tokenId) public view returns (uint256) {
        //todo: calculate reputation using lens protocol or phi land score or gitcoin passport

        return lensBorrowers[_tokenId].reputation;
    }

    // Function to get the debt balance of a Lens profile
    function getDebt(uint256 _tokenId) external view returns (uint256) {
        return lensBorrowers[_tokenId].debt;
    }

    /// @dev Lenders can supply USDC to the lending pool
    function supply(uint256 _amount) external {
        require(usdc.balanceOf(msg.sender) >= _amount, "Insufficient USDC balance");

        UsdcLender memory newLender;
        newLender.lender = msg.sender;
        newLender.suppliedBalance += _amount;
        lenders[msg.sender] = newLender;

        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev Lenders can withdraw their USDC from the lending pool
    function withdraw(uint256 _amount) external {
        require(lenders[msg.sender].suppliedBalance >= _amount, "Insufficient supplied balance");

        UsdcLender storage lender = lenders[msg.sender];
        lender.suppliedBalance -= _amount;
        lenders[msg.sender] = lender;

        usdc.transfer(msg.sender, _amount);
    }

    /// @dev Liquidate a Lens profile borrower if their debt is too high
    function liquidate(uint256 _tokenId) external {
        LensBorrower storage borrower = lensBorrowers[_tokenId];
        require(borrower.debt > 0, "Lens profile has no debt");

        //todo: take their NFT and sell it on the market to repay the debt
    }

}
