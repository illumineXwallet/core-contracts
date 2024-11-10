import * as hre from "hardhat";

const main = async function () {
    const { deployments } = hre;

    const ComplianceManager = await hre.ethers.getContractAt("ComplianceManager", (await deployments.get("ComplianceManager")).address);
    const SapphireEndpoint = await hre.ethers.getContractAt(
        "SapphireEndpoint",
        (await deployments.get("SapphireEndpoint")).address
    );

    await ComplianceManager.setAllowedPusher(await SapphireEndpoint.getAddress(), await SapphireEndpoint.RECORD_TYPE());
}

main();