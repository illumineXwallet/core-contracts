import * as hre from "hardhat";
import fs from "fs";

const main = async function () {
    const { deployments, config } = hre;

    const CrossChainVaultApp = await hre.ethers.getContractAt(
        "CrossChainVaultApp",
        (await deployments.get("CrossChainVaultApp")).address
    );

    const otherNetworks = fs.readdirSync(`./deployments`).filter(fl => !fl.startsWith("sapphire"));

    await CrossChainVaultApp.setAllowedSenders(otherNetworks.map((netName) => {
        const filename = `./deployments/${netName}/CrossChainVaultApp.json`;
        const deployment = JSON.parse(fs.readFileSync(filename, 'utf-8'));

        const net = config.networks[netName];
        if (!net.chainId) {
            throw new Error(`Not chainId set for ${netName}`);
        }

        return {
            srcChainId: net.chainId,
            sender: deployment.address,
            isAllowed: true,
        }
    }))
}

main();