import * as hre from "hardhat";
import {ASSETS_LIST, chainIdToEnumChainId} from "../../../utils/lists";
import {getChainId} from "hardhat";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const CrossChainVault = await hre.ethers.getContractAt("CrossChainVault", (await deployments.get("CrossChainVault")).address);
    await CrossChainVault.setAllowedAssets(ASSETS_LIST[chainIdToEnumChainId(await getChainId())].map(asset => ({
        asset: asset.token,
        isAllowed: true
    })));
}

main();