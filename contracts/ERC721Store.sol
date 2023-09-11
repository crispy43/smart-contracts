// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./Royalties.sol";

contract ERC721Store is
  Initializable,
  ERC721Upgradeable,
  ERC721URIStorageUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  ERC721BurnableUpgradeable,
  Royalties,
  UUPSUpgradeable
{
  using CountersUpgradeable for CountersUpgradeable.Counter;
  CountersUpgradeable.Counter private _tokenIdCounter;

  bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  // * 기본 approval (거래 컨트랙트 중계 허용)
  mapping(address => bool) private defaultApprovals;
  event SetDefaultApproval(address indexed operator, bool hasApproval);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize() initializer public {
    __ERC721_init("PsuB ERC721 Store", "PsuB721"); // name, symbol
    __ERC721URIStorage_init();
    __Pausable_init();
    __AccessControl_init();
    __ERC721Burnable_init();
    __Royalties_init(1000); // 로열티 최대치, 1000 = 10%
    __UUPSUpgradeable_init();
    
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(SETTER_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
  }

  // * Version
  function version() virtual public pure returns (string memory) {
    return "1";
  }

  // * 기본 승인 지정
  function setDefaultApproval(
    address operator,
    bool hasApproval
  ) virtual public onlyRole(SETTER_ROLE) {
    require(operator != address(0), "ERC721Store: invalid operator");
    defaultApprovals[operator] = hasApproval;
    emit SetDefaultApproval(operator, hasApproval);
  }

  // * create
  // 로열티 등록
  function create(
    address to,
    string memory uri,
    Royalty[] memory authors
  ) virtual public whenNotPaused {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _setRoyalties(tokenId, authors);
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  // * safeMint
  // 로열티와 등록 없이 민팅
  function safeMint(
    address to,
    string memory uri
  ) virtual public whenNotPaused {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  // * isApprovedForAll defaultApproval 조건 추가
  function isApprovedForAll(
    address owner,
    address operator
  ) override
    virtual
    public
    view
    returns (bool)
  {
    return defaultApprovals[operator] || super.isApprovedForAll(owner, operator);
  }

  // * 로열티 최대치 권한 제한
  function setMaxRoyalty(
    uint96 maxRoyalty_
  ) override virtual external onlyRole(SETTER_ROLE) {
    maxRoyalty = maxRoyalty_;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) override internal whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(
    address newImplementation
  ) override internal onlyRole(UPGRADER_ROLE) {}

  function _burn(
    uint256 tokenId
  ) override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    internal
  {
    super._burn(tokenId);
  }

  function tokenURI(
    uint256 tokenId
  ) override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    public
    view
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) override(ERC721Upgradeable, AccessControlUpgradeable)
    virtual
    public
    view
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
