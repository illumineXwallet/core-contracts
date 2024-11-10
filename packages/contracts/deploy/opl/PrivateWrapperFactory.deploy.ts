import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    await deploy("PrivateWrapperFactory", {
        from: deployer,
        log: true,
        gasLimit: 10_000_000
    });
}

func.tags = ["PrivateWrapperFactory"];

export default func;