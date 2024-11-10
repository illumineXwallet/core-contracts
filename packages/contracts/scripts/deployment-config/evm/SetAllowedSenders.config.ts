import * as hre from "hardhat";
import {chainIdToEnumChainId, TESTNETS} from "../../../utils/lists";
import {getChainId} from "hardhat";
import fs from "fs";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const CrossChainVaultApp = await hre.ethers.getContractAt(
        "CrossChainVaultApp",
        (await deployments.get("CrossChainVaultApp")).address
    );

    const MultichainEndpoint = await hre.ethers.getContractAt(
        "MultichainEndpoint",
        (await deployments.get("MultichainEndpoint")).address
    );

    const isTestnet = TESTNETS.includes(chainIdToEnumChainId(await getChainId()));

    const filename = `./deployments/${isTestnet ? `sapphire_testnet` : `sapphire_mainnet`}/CrossChainVaultApp.json`;
    const deployment = JSON.parse(fs.readFileSync(filename, 'utf-8'));

    await CrossChainVaultApp.setAllowedSenders([
        {
            srcChainId: await MultichainEndpoint.SAPPHIRE_CHAINID(),
            sender: deployment.address,
            isAllowed: true
        }
    ]);
}

main();