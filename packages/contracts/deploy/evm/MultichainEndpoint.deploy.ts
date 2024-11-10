import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {chainIdToEnumChainId, TESTNETS} from "../../utils/lists";
import {getChainId} from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const CrossChainVaultApp = await deployments.get("CrossChainVaultApp");

    await deploy("MultichainEndpoint", {
        from: deployer,
        log: true,
        args: [CrossChainVaultApp.address, TESTNETS.includes(chainIdToEnumChainId(await getChainId()))]
    });
}

func.tags = ["MultichainEndpoint"];
func.dependencies = ["CrossChainVaultApp"];

export default func;