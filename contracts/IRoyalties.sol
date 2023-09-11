// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoyalties {
  // * 로열티 구조체
  struct Royalty {
    address author;
    uint96 fraction; // 로열티 지분율, 1000 = 10%
  }

  // * 로열티 변경 이벤트
  event SetRoyalties(uint256 tokenId, Royalty[] creators);

  // * 로열티 조회
  function royalties(uint256 tokenId) external view returns (Royalty[] memory);

  // * 로열티 최대치 변경
  function setMaxRoyalty(uint96 maxRoyalty_) external;

  // * ERC2981
  function royaltyInfo(
    uint256 _tokenId,
    uint256 _salePrice
  ) external view returns (
    address receiver,
    uint256 royaltyAmount
  );
}
