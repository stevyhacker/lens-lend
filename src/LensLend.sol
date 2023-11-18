import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LensLend {
    struct LensBorrower {
        uint256 lensProfileTokenId;
        uint256 reputation;
        uint256 debt;
    }

    struct UsdcLenders {
        address lender;
        uint256 suppliedBalance;
    }

    mapping(uint256 => LensBorrower) private lensBorrowers;
    mapping(address => UsdcLenders) private lenders;

    // Constants
    IERC20 public immutable usdc;
    IERC721 public immutable lensProfileCollection;

    constructor(address _usdcAddress, address _lensProfileCollection) {
        usdcAddress = IERC20(_usdcAddress);
        lensProfileCollection = IERC721(_lensProfileCollection);
    }

    function addNewBorrower(uint256 _lensProfileTokenId, uint256 _reputation) external {
        LensBorrower storage profile = lensBorrowers[_lensProfileTokenId];
        profile.reputation = _reputation;
        _mint(msg.sender, _tokenId);
    }

    // Function to borrow USDC against Lens profile NFT
    function borrow(uint256 _tokenId, uint256 _amount) external {
        require(lensProfileCollection.ownerOf(_tokenId) == msg.sender, "Only the owner can borrow");
        LensBorrower storage borrower = lensBorrowers[_tokenId];
        require(borrower.debt == 0, "Lens profile already borrowed the maximum amount");

        require(usdc.balanceOf(address(this)) >= _amount, "Insufficient USDC balance in the lending pool");

        borrower.debt += _amount;
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
    function getReputation(uint256 _tokenId) external view returns (uint256) {
        //todo: calculate reputation
        return lensProfiles[_tokenId].reputation;
    }

    // Function to get the debt balance of a Lens profile
    function getDebt(uint256 _tokenId) external view returns (uint256) {
        return lenders[_tokenId].debt;
    }
}
