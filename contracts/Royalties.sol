// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./IRoyalties.sol";

contract Royalties is Initializable, IRoyalties {
  uint96 public maxRoyalty; // 로열티 최대치, 1000 = 10%
  mapping(uint256 => Royalty[]) private _royalties;

  function __Royalties_init(uint96 maxRoyalty_) internal onlyInitializing {
    __Royalties_init_unchained(maxRoyalty_);
  }

  function __Royalties_init_unchained(uint96 maxRoyalty_) internal onlyInitializing {
    maxRoyalty = maxRoyalty_;
  }

  // * 로열티 조회
  function royalties(uint256 tokenId)
    override
    virtual
    external
    view
    returns (Royalty[] memory)
  {
    return _royalties[tokenId];
  }

  // * 로열티 최대치 변경
  function setMaxRoyalty(uint96 maxRoyalty_) override virtual external {
    maxRoyalty = maxRoyalty_;
  }

  // * 로열티 등록
  function _setRoyalties(uint256 id, Royalty[] memory authors) virtual internal {
    uint256 totalFraction;
    for (uint i = 0; i < authors.length; i++) {
      require(authors[i].author != address(0x0), "Royalties: invalid author");
      require(authors[i].fraction != 0, "Royalties: fraction should be positive");
      totalFraction += authors[i].fraction;
      _royalties[id].push(authors[i]);
    }
    require(totalFraction <= maxRoyalty, "Royalties: invalid fractions");
    emit SetRoyalties(id, authors);
  }

  // * ERC2981
  function royaltyInfo(
    uint256 _tokenId,
    uint256 _salePrice
  ) override virtual external view returns (
    address receiver,
    uint256 royaltyAmount
  ) {
    if (_royalties[_tokenId].length == 0) {
      receiver = address(0);
      royaltyAmount = 0;
      return(receiver, royaltyAmount);
    }
    Royalty[] memory _finded = _royalties[_tokenId];
    receiver = _finded[0].author;
    uint percent;
    for (uint i = 0; i < _finded.length; i++) {
      percent += _finded[i].fraction;
    }
    royaltyAmount = percent * _salePrice / 10000;
  }
}
