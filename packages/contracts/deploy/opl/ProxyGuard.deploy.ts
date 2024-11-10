import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    const SapphireEndpoint = await deployments.get("SapphireEndpoint");

    await deploy("ProxyGuard", {
        from: deployer,
        log: true,
        args: [SapphireEndpoint.address]
    });
}

func.tags = ["ProxyGuard"];
func.dependencies = ["SapphireEndpoint"];

export default func;