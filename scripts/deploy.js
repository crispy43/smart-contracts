const { ethers, upgrades } = require('hardhat');

async function main() {
  // * NFT Exchange
  const NFTExchange = await ethers.getContractFactory('NFTExchange');
  const contract = await upgrades.deployProxy(NFTExchange,
    {
      maxFeePerGas: '1500000014',
      maxPriorityFeePerGas: '1500000000',
    },
  );
  await contract.deployed();
  console.log('proxy address:', contract.address);

  // * ERC-721
  // const ERC721Store = await ethers.getContractFactory('ERC721Store');
  // const contract = await upgrades.deployProxy(ERC721Store,
  //   {
  //     maxFeePerGas: '1500000014',
  //     maxPriorityFeePerGas: '1500000000',
  //   },
  // );
  // await contract.deployed();
  // console.log('proxy address:', contract.address);

  // * ERC-1155
  // const ERC1155Store = await ethers.getContractFactory('ERC1155Store');
  // const contract = await upgrades.deployProxy(ERC1155Store,
  //   {
  //     maxFeePerGas: '1500000014',
  //     maxPriorityFeePerGas: '1500000000',
  //   },
  // );
  // await contract.deployed();
  // console.log('proxy address:', contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
