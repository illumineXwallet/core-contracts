import * as hre from "hardhat";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const CrossChainVaultApp = await hre.ethers.getContractAt("CrossChainVaultApp", (await deployments.get("CrossChainVaultApp")).address);
    const MultichainEndpoint = await hre.ethers.getContractAt(
        "SapphireEndpoint",
        (await deployments.get("SapphireEndpoint")).address
    );

    await CrossChainVaultApp.setActualEndpoint(await MultichainEndpoint.getAddress());
}

main();