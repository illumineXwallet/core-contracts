import * as hre from "hardhat";
import fs from "fs";

const main = async function () {
    const { deployments, config } = hre;

    const SapphireEndpoint = await hre.ethers.getContractAt(
        "SapphireEndpoint",
        (await deployments.get("SapphireEndpoint")).address
    );

    const otherNetworks = fs.readdirSync(`./deployments`).filter(fl => !fl.startsWith("sapphire"));

    await SapphireEndpoint.setConnectedEndpoints(otherNetworks.map((netName) => {
        const filename = `./deployments/${netName}/CrossChainVaultApp.json`;
        const deployment = JSON.parse(fs.readFileSync(filename, 'utf-8'));

        const net = config.networks[netName];
        if (!net.chainId) {
            throw new Error(`Not chainId set for ${netName}`);
        }

        return {
            contractAddress: deployment.address,
            chainId: net.chainId
        }
    }))
}

main();