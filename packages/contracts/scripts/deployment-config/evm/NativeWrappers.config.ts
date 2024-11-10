import * as hre from "hardhat";
import {chainIdToEnumChainId, NATIVE_WRAPPERS} from "../../../utils/lists";
import {getChainId} from "hardhat";

const main = async function () {
    const { deployments, getNamedAccounts } = hre;

    const MultichainEndpoint = await hre.ethers.getContractAt(
        "MultichainEndpoint",
        (await deployments.get("MultichainEndpoint")).address
    );

    await MultichainEndpoint.setNativeWrapper(NATIVE_WRAPPERS[chainIdToEnumChainId(await getChainId())]);
}

main();