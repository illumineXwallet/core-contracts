import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer } = await getNamedAccounts();

    await deploy("EncryptedDeployer", {
        from: deployer,
        log: true,
        args: ["0x5Fa135a5C3B4C557520B0ebb46CcFB56bD39c375"]
    });
}

func.tags = ["EncryptedDeployer"];

export default func;