// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./IRoyalties.sol";

contract NFTExchange is Initializable, OwnableUpgradeable, EIP712Upgradeable {
  uint96 public exchangeFee; // 거래 수수료, 100 = 1.00%
  mapping(address => bool) private _payableTokens; // 지불 가능한 ERC20 계약 주소
  mapping(bytes32 => Bid) private _bids; // 등록된 입찰

  event SetPayableToken(address indexed token, bool isAvailable);
  event SetBid(address indexed bidder, Bid bid);
  event DeleteBid(address indexed bidder, Bid bid);
  event Buy(address indexed seller, address indexed buyer, Ask ask);
  event Sell(address indexed seller, address indexed buyer, Bid bid);

  // * 주문 구조체
  struct Ask {
    address tokenStorage;
    uint128 tokenType;
    uint256 tokenId;
    uint256 amount;
    uint256 price;
    uint256 startTime;
    uint256 endTime;
    bytes signature;
  }
  struct Bid {
    address tokenStorage;
    uint128 tokenType;
    uint256 tokenId;
    uint256 amount;
    address payableToken;
    uint256 price;
    uint256 startTime;
    uint256 endTime;
    address bidder;
  }

  function __NFTExchange_init(uint96 exchangeFee_) internal onlyInitializing {
    __NFTExchange_init_unchained(exchangeFee_);
  }

  function __NFTExchange_init_unchained(uint96 exchangeFee_) internal onlyInitializing {
    exchangeFee = exchangeFee_;
  }

  function initialize() initializer public {
    __Ownable_init();
    __NFTExchange_init(250); // 거래 수수료, 100 = 1.00%
    __EIP712_init("PsuB NFT Exchange", "1"); // 도메인 name, version
  }

  // * 지불 가능한 ERC20 주소 여부
  function isPayableToken(address token) virtual public view returns (bool) {
    return _payableTokens[token];
  }

  // * 지불 가능한 ERC20 주소 설정
  function setPayableToken(address token, bool isAvailable) virtual external onlyOwner {
    _payableTokens[token] = isAvailable;
    emit SetPayableToken(token, isAvailable);
  }

  // * 구매
  function buy(Ask calldata ask)
    virtual
    external
    payable
    returns (address)
  {
    require(ask.tokenType == 721 || ask.tokenType == 1155, "NFTExchange: invalid token type");
    require(msg.value >= ask.price, "NFTExchange: sended value is not enough");
    address signer = _askVerify(ask);
    IRoyalties iRoyalties = IRoyalties(ask.tokenStorage);
    IRoyalties.Royalty[] memory _royalties = iRoyalties.royalties(ask.tokenId);
    uint256 remain = ask.price;
    uint256 exchangeFeeAmount = exchangeFee * ask.price / 10000;

    // * 거래 수수료 지불
    payable(owner()).transfer(exchangeFeeAmount);
    remain -= exchangeFeeAmount;

    // * 로열티 지불
    for (uint i = 0; i < _royalties.length; i++) {
      uint256 royaltyAmount = _royalties[i].fraction * ask.price / 10000;
      payable(_royalties[i].author).transfer(royaltyAmount);
      remain -= royaltyAmount;
    }

    // * 남은 금액 판매자에게 지불
    payable(signer).transfer(remain);

    // * NFT 전송
    if (ask.tokenType == 721) {
      IERC721Upgradeable(ask.tokenStorage).safeTransferFrom(
        signer,
        _msgSender(),
        ask.tokenId,
        ""
      );
    } else if (ask.tokenType == 1155) {
      IERC1155Upgradeable(ask.tokenStorage).safeTransferFrom(
        signer,
        _msgSender(),
        ask.tokenId,
        ask.amount,
        ""
      );
    }

    emit Buy(signer, _msgSender(), ask);
    return signer;
  }

  // * Bid 해시 값
  function getBidHash(Bid calldata bid) virtual external view returns(bytes32) {
    return _bidHash(bid);
  }

  // * Bid 조회
  function getBid(bytes32 bidHash) virtual external view returns(Bid memory) {
    return _bids[bidHash];
  }

  // * Bid 등록
  function setBid(
    address tokenStorage,
    uint128 tokenType,
    uint256 tokenId,
    uint256 amount,
    address payableToken,
    uint256 price,
    uint256 startTime,
    uint256 endTime
  ) virtual external returns(bytes32) {
    Bid memory bid = Bid(
      tokenStorage,
      tokenType,
      tokenId,
      amount,
      payableToken,
      price,
      startTime,
      endTime,
      _msgSender()
    );
    bytes32 bidHash = _bidHash(bid);
    _bids[bidHash] = bid;
    emit SetBid(_msgSender(), bid);
    return bidHash;
  }

  // * Bid 삭제
  function deleteBid(bytes32 bidHash) virtual external {
    Bid memory bid = _bids[bidHash];
    require(bid.bidder != address(0), "NFTExchange: bid is not founded");
    require(bid.bidder == _msgSender(), "NFTExchange: caller is not bidder");
    delete _bids[bidHash];
    emit DeleteBid(_msgSender(), bid);
  }

  // * 판매
  function sell(bytes32 bidHash) virtual external returns(address) {
    Bid memory bid = _bids[bidHash];
    require(bid.bidder != address(0), "NFTExchange: bid is not founded");
    require(bid.tokenType == 721 || bid.tokenType == 1155, "NFTExchange: invalid token type");
    require(isPayableToken(bid.payableToken), "NFTExchange: invalid payable token");
    IERC20Upgradeable erc20 = IERC20Upgradeable(bid.payableToken);

    uint256 erc20Balance = erc20.balanceOf(bid.bidder);
    require(erc20Balance >= bid.price, "NFTExchange: bidder token is not enough");
    uint256 erc20Allowance = erc20.allowance(bid.bidder, address(this));
    require(erc20Allowance >= bid.price, "NFTExchange: bidder token allowance is not enough");

    IRoyalties iRoyalties = IRoyalties(bid.tokenStorage);
    IRoyalties.Royalty[] memory _royalties = iRoyalties.royalties(bid.tokenId);
    uint256 remain = bid.price;
    uint256 exchangeFeeAmount = exchangeFee * bid.price / 10000;

    // * 거래 수수료 지불
    erc20.transferFrom(bid.bidder, owner(), exchangeFeeAmount);
    remain -= exchangeFeeAmount;

    // * 로열티 지불
    for (uint i = 0; i < _royalties.length; i++) {
      uint256 royaltyAmount = _royalties[i].fraction * bid.price / 10000;
      erc20.transferFrom(bid.bidder, _royalties[i].author, royaltyAmount);
      remain -= royaltyAmount;
    }

    // * 남은 금액 판매자에게 지불
    erc20.transferFrom(bid.bidder, _msgSender(), remain);

    // * NFT 전송
    if (bid.tokenType == 721) {
      IERC721Upgradeable(bid.tokenStorage).safeTransferFrom(
        _msgSender(),
        bid.bidder,
        bid.tokenId,
        ""
      );
    } else if (bid.tokenType == 1155) {
      IERC1155Upgradeable(bid.tokenStorage).safeTransferFrom(
        _msgSender(),
        bid.bidder,
        bid.tokenId,
        bid.amount,
        ""
      );
    }
    
    emit Sell(_msgSender(), bid.bidder, bid);
    return bid.bidder;
  }

  // * EIP712 Ask hash
  function _askHash(Ask calldata ask)
    virtual
    internal
    view
    returns (bytes32)
  {
    return _hashTypedDataV4(keccak256(abi.encode(
      keccak256(
        "Ask(address tokenStorage,uint128 tokenType,uint256 tokenId,uint256 amount,uint256 price,uint256 startTime,uint256 endTime)"
      ),
      ask.tokenStorage,
      ask.tokenType,
      ask.tokenId,
      ask.amount,
      ask.price,
      ask.startTime,
      ask.endTime
    )));
  }

  // * Ask 검증
  function _askVerify(Ask calldata ask)
    virtual
    internal
    view
    returns (address)
  {
    bytes32 digest = _askHash(ask);
    return ECDSAUpgradeable.recover(digest, ask.signature);
  }

  // * Bid hash
  function _bidHash(Bid memory bid)
    virtual
    internal
    view
    returns (bytes32)
  {
    return keccak256(abi.encode(
      keccak256(
        "Bid(address tokenStorage,uint128 tokenType,uint256 tokenId,uint256 amount,address payableToken,uint256 price,uint256 startTime,uint256 endTime,address bidder)"
      ),
      bid.tokenStorage,
      bid.tokenType,
      bid.tokenId,
      bid.amount,
      bid.payableToken,
      bid.price,
      bid.startTime,
      bid.endTime,
      bid.bidder
    ));
  }

  // * 체인 ID 조회
  function getChainID() public view returns (uint256 id) {
    assembly {
      id := chainid()
    }
  }
}
