import * as hre from "hardhat";
import {chainIdToEnumChainId, TESTNETS} from "../../../utils/lists";
import {getChainId} from "hardhat";
import fs from "fs";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const MultichainEndpoint = await hre.ethers.getContractAt(
        "MultichainEndpoint",
        (await deployments.get("MultichainEndpoint")).address
    );

    const isTestnet = TESTNETS.includes(chainIdToEnumChainId(await getChainId()));

    const filename = `./deployments/${isTestnet ? `sapphire_testnet` : `sapphire_mainnet`}/CrossChainVaultApp.json`;
    const deployment = JSON.parse(fs.readFileSync(filename, 'utf-8'));

    await MultichainEndpoint.setConnectedEndpoints([
        {
            chainId: await MultichainEndpoint.SAPPHIRE_CHAINID(),
            contractAddress: deployment.address
        }
    ]);
}

main();