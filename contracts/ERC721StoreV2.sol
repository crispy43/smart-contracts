// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721Store.sol";

contract ERC721StoreV2 is ERC721Store {
  function proxyVersion() pure public returns(uint) {
    return 2;
  }
}
