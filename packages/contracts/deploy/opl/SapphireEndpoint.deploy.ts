import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {chainIdToEnumChainId, SAPPHIRE_TESTNETS} from "../../utils/lists";
import {getChainId} from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const chainId = chainIdToEnumChainId(await getChainId());

    const CrossChainVaultApp = await deployments.get("CrossChainVaultApp");
    const PrivateWrapperFactory = await deployments.get("PrivateWrapperFactory");
    const ComplianceManager = await deployments.get("ComplianceManager");

    await deploy("SapphireEndpoint", {
        from: deployer,
        log: true,
        args: [
            PrivateWrapperFactory.address,
            CrossChainVaultApp.address,
            ComplianceManager.address,
            hre.ethers.randomBytes(32),
            SAPPHIRE_TESTNETS.includes(chainId)
        ]
    });
}

func.tags = ["SapphireEndpoint"];
func.dependencies = ["CrossChainVaultApp", "PrivateWrapperFactory", "ComplianceManager"];

export default func;