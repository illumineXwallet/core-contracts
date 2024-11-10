import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const PrivateWrapperFactory = await deployments.get("PrivateWrapperFactory");

    await deploy("DepositVault", {
        from: deployer,
        log: true,
        args: [deployer, PrivateWrapperFactory.address]
    });
}

func.tags = ["DepositVault"];
func.dependencies = ["PrivateWrapperFactory"];

export default func;