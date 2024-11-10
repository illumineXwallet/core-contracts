import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const MultichainEndpoint = await deployments.get("MultichainEndpoint");

    await deploy("AMLGate", {
        from: deployer,
        log: true,
        args: [MultichainEndpoint.address]
    });
}

func.tags = ["AMLGate"];
func.dependencies = ["MultichainEndpoint"];

export default func;