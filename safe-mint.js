const ethers = require('ethers');

const provider = new ethers.providers.JsonRpcProvider({
  url: 'https://ropsten.infura.io/v3/',
});
const contractAddress = '0xE9Cf59540D87584Ba53C0084367Ed3e13f3325c5';
const abi = require('./artifacts/contracts/ERC1155Store.sol/ERC1155Store.json').abi;

const account = new ethers.Wallet(/* private key */);
const signer = account.connect(provider);
const contractWithSigner = new ethers.Contract(contractAddress, abi, signer);

(async () => {
  try {
    // * safe mint
    const result = await contractWithSigner.safeMint(
      '', // address
      'http://test.json', // metadata
      {
        maxFeePerGas: '1500000014',
        maxPriorityFeePerGas: '1500000000',
      },
    );
    console.log(result);
  } catch (error) {
    console.error(error);
  }
});
