const fs = require("fs");
const path = require("path");
import { HardhatUpgrades } from "@openzeppelin/hardhat-upgrades/src"
import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("deploy", "Deploy contract")
  .addPositionalParam("name", "The contract name")
  .addPositionalParam("symbol", "The token symbol")
  .setAction(async ({ name, symbol }: { name: string, symbol: string }, env: HardhatRuntimeEnvironment) => {
    const { network, ethers, upgrades } = env as HardhatRuntimeEnvironment & { upgrades: HardhatUpgrades };

    if (network.name === "hardhat") {
      console.warn(
        "You are running the faucet task with Hardhat network, which" +
        "gets automatically created and destroyed every time. Use the Hardhat" +
        " option '--network localhost'"
      );
    }

    const factory = await ethers.getContractFactory("CALM721");
    const CALM1155Deployment = await factory.deploy(name, symbol);
    const { address, deployTransaction }  = await CALM1155Deployment.deployed();


    const { gasUsed } = await deployTransaction.wait()

    console.log(`Deployed contract ${name} at address ${address} (tx hash ${deployTransaction.hash})
Gas used ${gasUsed}`);
  });