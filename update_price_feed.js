// Sepolia testnet ETH/USD price feed address
const sepoliaETHUSDFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

console.log("Correct Sepolia ETH/USD price feed address:", sepoliaETHUSDFeed);
console.log("\nTo update the price feed, call:");
console.log(`seth send <CONTRACT_ADDRESS> 'setEthUsdPriceFeed(address)' ${sepoliaETHUSDFeed} --from <OWNER_ADDRESS>`);