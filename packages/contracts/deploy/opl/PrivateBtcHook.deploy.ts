import "hardhat-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const factory = await deployments.get("PrivateWrapperFactory");

  await deploy("BtcToPrivateBtcHook", {
    from: deployer,
    log: true,
    args: ["0x847E32bd2274038f4de7b56244e496708C4A19BC", factory.address],
  });
};

func.tags = ["BtcToPrivateBtcHook"];
func.dependencies = ["PrivateWrapperFactory"];

export default func;
