import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {CELER_MESSAGE_BUS, chainIdToEnumChainId} from "../../utils/lists";
import {getChainId} from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const CrossChainVault = await deployments.get("CrossChainVault");

    const messageBusAddress = CELER_MESSAGE_BUS[chainIdToEnumChainId(await getChainId())];
    if (!messageBusAddress) {
        throw new Error("Invalid messageBusAddress");
    }

    await deploy("CrossChainVaultApp", {
        from: deployer,
        log: true,
        args: [CrossChainVault.address, messageBusAddress]
    });
}

func.tags = ["CrossChainVaultApp"];
func.dependencies = ["CrossChainVault"];

export default func;