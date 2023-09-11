const { ethers, upgrades } = require('hardhat');

async function main() {
  // const ERC721StoreV2 = await ethers.getContractFactory('ERC721StoreV2');
  // const contract = await upgrades.upgradeProxy('0xcc71679F3B9750635213902f6594ca9F784E90Fe', ERC721StoreV2, {
  //   maxFeePerGas: '1500000014',
  //   maxPriorityFeePerGas: '1500000000',
  // },);
  // console.log('Upgrade Implementation address:', contract);

  const ERC1155StoreV2 = await ethers.getContractFactory('ERC1155StoreV2');
  const contract = await upgrades.upgradeProxy('0x9F57239C154a6604A6BD49909D3B4e8cFee6ED63', ERC1155StoreV2, {
    maxFeePerGas: '1500000014',
    maxPriorityFeePerGas: '1500000000',
  },);
  console.log('Upgrade Implementation address:', contract);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
