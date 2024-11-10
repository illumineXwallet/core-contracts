import * as hre from "hardhat";

const main = async () => {
    const { deployments, getNamedAccounts } = hre;

    const AMLGate = await hre.ethers.getContractAt("AMLGate", (await deployments.get("AMLGate")).address);
    const MultichainEndpoint = await hre.ethers.getContractAt(
        "MultichainEndpoint",
        (await deployments.get("MultichainEndpoint")).address
    );

    await (await MultichainEndpoint.setTrustedForwarder(await AMLGate.getAddress())).wait();
    await MultichainEndpoint.toggleAllowedSender(await AMLGate.getAddress());
}

main();