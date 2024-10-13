import { HardhatUserConfig } from "hardhat/types";
import '@openzeppelin/hardhat-upgrades';
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
import "@nomicfoundation/hardhat-ignition-ethers";

// Updated variable names for BaseSepoliaTestnet
const { API_URL, PRIVATE_KEY, API_KEY } = process.env;

if (!PRIVATE_KEY) {
  throw new Error("Please set your BASE_SEPOLIA_PRIVATE_KEY in the .env file");
}

const config: HardhatUserConfig = {
  solidity: "0.8.24",

  networks: {
    base_sepolia: {
      url: API_URL || "https://sepolia.base.org", // Default to Base Sepolia RPC URL if not defined
      accounts: [PRIVATE_KEY],
      chainId: 84532, // Use default chainId for Base Sepolia
    },
  },

  etherscan: {
    apiKey: API_KEY || "", // Fallback for BASESCAN_API_KEY
    customChains: [
      {
        network: "base_sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
    ],
  },
};

export default config;
