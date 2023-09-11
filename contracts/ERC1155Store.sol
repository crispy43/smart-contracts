// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./Royalties.sol";

contract ERC1155Store is
  Initializable,
  ERC1155Upgradeable,
  AccessControlUpgradeable,
  PausableUpgradeable,
  ERC1155BurnableUpgradeable,
  ERC1155SupplyUpgradeable,
  Royalties,
  UUPSUpgradeable
{
  using CountersUpgradeable for CountersUpgradeable.Counter;
  CountersUpgradeable.Counter private _tokenIdCounter;

  bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  // * name, symbol
  string public name;
  string public symbol;

  // * 기본 approval (거래 컨트랙트 중계 허용)
  mapping(address => bool) private defaultApprovals;
  event SetDefaultApproval(address indexed operator, bool hasApproval);

  // * creators
  mapping (uint256 => address) public creators;
  event SetCreator(
    uint256 id, address
    indexed oldCreator,
    address indexed newCreator
  );

  // * uris
  mapping (uint256 => string) private _customUris;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function __ERC1155Store_init(
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    __ERC1155Store_init_unchained(name_, symbol_);
  }

  function __ERC1155Store_init_unchained(
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    name = name_;
    symbol = symbol_;
  }

  function initialize() initializer public {
    __ERC1155_init(""); // uri
    __AccessControl_init();
    __Pausable_init();
    __ERC1155Burnable_init();
    __ERC1155Supply_init();
    __Royalties_init(1000); // 로열티 최대치, 1000 = 10%
    __ERC1155Store_init("PsuB ERC1155 Store", "PsuB1155"); // name, symbol
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(SETTER_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
  }

  // * Version
  function version() virtual public pure returns (string memory) {
    return "1";
  }

  // * 크리에이터만
  modifier onlyCreator(uint256 id) {
    require(creators[id] == _msgSender(), "ERC1155Store: caller is not creator");
    _;
  }

  // * 민팅된 경우에만
  modifier onlyExists(uint256 id) {
    require(exists(id), "ERC1155Store: token is not exists");
    _;
  }

  // * creator 변경
  function setCreator(
    uint256 id,
    address newCreator
  ) virtual public onlyCreator(id) {
    require(newCreator != address(0), "ERC1155Store: invalid operator");
    address oldCreator = creators[id];
    creators[id] = newCreator;
    emit SetCreator(id, oldCreator, newCreator);
  }

  // * 기본 승인 지정
  function setDefaultApproval(
    address operator,
    bool hasApproval
  ) virtual public onlyRole(SETTER_ROLE) {
    require(operator != address(0), "ERC1155Store: invalid operator");
    defaultApprovals[operator] = hasApproval;
    emit SetDefaultApproval(operator, hasApproval);
  }

  // * create
  // 로열티와 creator 등록
  function create(
    address account,
    uint256 amount,
    bytes memory data,
    string memory uri_,
    Royalty[] memory authors
  ) virtual external whenNotPaused {
    uint256 id = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _mint(account, id, amount, data);
    _setRoyalties(id, authors);
    creators[id] = account;
    _customUris[id] = uri_;
    emit SetCreator(id, address(0), account);
  }

  // * 추가 민팅
  function additionalMint(
    address account,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) virtual
    public
    onlyRole(MINTER_ROLE)
    onlyCreator(id)
    whenNotPaused
  {
    _mint(account, id, amount, data);
  }

  // * isApprovedForAll defaultApproval 조건 추가
  function isApprovedForAll(
    address owner,
    address operator
  ) override virtual public view returns (bool) {
    return defaultApprovals[operator] || super.isApprovedForAll(owner, operator);
  }

  // * uri 조회
  function uri(
    uint256 id
  ) override virtual public view returns (string memory) {
    bytes memory customUriBytes = bytes(_customUris[id]);
    if (customUriBytes.length > 0) {
      return _customUris[id];
    } else {
      return super.uri(id);
    }
  }

  // * 로열티 최대치 권한 제한
  function setMaxRoyalty(
    uint96 maxRoyalty_
  ) override virtual external onlyRole(SETTER_ROLE) {
    maxRoyalty = maxRoyalty_;
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  )
    override(ERC1155Upgradeable,ERC1155SupplyUpgradeable)
    virtual
    internal
    whenNotPaused
  {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }

  function setURI(string memory newuri) public onlyRole(SETTER_ROLE) {
    _setURI(newuri);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(
    address newImplementation
  ) internal onlyRole(UPGRADER_ROLE) override {}

  // The following functions are overrides required by Solidity.
  function supportsInterface(
    bytes4 interfaceId
  ) override(ERC1155Upgradeable, AccessControlUpgradeable)
    public
    view
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
