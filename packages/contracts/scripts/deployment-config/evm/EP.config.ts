import * as hre from "hardhat";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const CrossChainVaultApp = await hre.ethers.getContractAt("CrossChainVaultApp", (await deployments.get("CrossChainVaultApp")).address);
    const MultichainEndpoint = await hre.ethers.getContractAt(
        "MultichainEndpoint",
        (await deployments.get("MultichainEndpoint")).address
    );

    await CrossChainVaultApp.setActualEndpoint(await MultichainEndpoint.getAddress());
}

main();