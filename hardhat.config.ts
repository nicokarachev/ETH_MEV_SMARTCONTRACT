import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28", // or the version you use
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,   // 👈 this fixes "stack too deep"
    },
  },
};

export default config;
