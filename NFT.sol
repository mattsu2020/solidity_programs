// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {OGLevel} from "./util.sol";

contract NFT is Initializable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant BLACKLIST_MANAGEMENT_ROLE = keccak256("BLACKLIST_MANAGEMENT_ROLE");
    uint256 private immutable maxSupplyPerLevel;
    string  public baseURI;
    uint256 public nextTokenId;

    // Mapping to keep track of the level of each NFT
    mapping(uint256 => uint256)   public tokenRecords;
    mapping(OGLevel => uint256)   public levels;
    mapping(OGLevel => uint256[]) public levelToTokenIDs;
    mapping(address => bool)      public isBlackListed;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[500] private __gap;

    event SafeMint(address _to, uint256 _tokenID, OGLevel _level);
    event DestroyedBlackFunds(address _blackListedUser, uint _balance);
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);

    constructor(uint256 _max) {
        maxSupplyPerLevel = _max;
    }

    function initialize(address defaultAdmin, string memory _name, string memory _symbol) initializer public {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        __ERC721Enumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        levels[OGLevel.Basic] = 20 ether;
        levels[OGLevel.Mid]   = 100 ether;
        levels[OGLevel.High]  = 500 ether;
    }

    function safeMint(address to, OGLevel _level) whenNotPaused public onlyRole(MINTER_ROLE) {
        require(!isBlackListed[to]);
        require((levelToTokenIDs[_level].length + 1) <= maxSupplyPerLevel, "cl");
        uint256 value = levels[_level];
        require(value > 0 , "cv");
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);

        tokenRecords[tokenId] = value;
        levelToTokenIDs[_level].push(tokenId);

        emit SafeMint(to, tokenId, _level);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(!isBlackListed[msg.sender] || !isBlackListed[from]);
        
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(!isBlackListed[msg.sender] || !isBlackListed[from]);

        super.safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) {
        require(!isBlackListed[msg.sender] || !isBlackListed[from]);

        super.transferFrom(from, to, tokenId);
    }

    function burn(uint256 tokenId) whenNotPaused public onlyRole((BURNER_ROLE)) {
        require(!isBlackListed[_ownerOf(tokenId)]);
        _burn(tokenId);
    }

    function setBaseURI(string memory _uri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _uri;
    }

    function _baseURI() internal view override returns (string memory) {
       return baseURI;
    }

    function getAmount(uint256 _tokenID) public view returns(uint256) {
        return tokenRecords[_tokenID];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        super._pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        super._unpause();
    }

    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function addBlackList (address _maker) public onlyRole(BLACKLIST_MANAGEMENT_ROLE) {
        isBlackListed[_maker] = true;
        emit AddedBlackList(_maker);
    }

    function removeBlackList (address _maker) public onlyRole(BLACKLIST_MANAGEMENT_ROLE) {
        isBlackListed[_maker] = false;
        emit RemovedBlackList(_maker);
    }

    function changeDefaultAdmin(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_account != address(0), "EOA: 0");
        _grantRole(DEFAULT_ADMIN_ROLE, _account);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
