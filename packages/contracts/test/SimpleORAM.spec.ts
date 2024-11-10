import {ethers} from "hardhat";
import { HDNodeWallet } from "ethers";
import * as sapphire from "@oasisprotocol/sapphire-paratime"
import {expect} from "chai";

describe('SimpleORAM', async () => {
    it('Balances consistency', async () => {
        const [me] = await ethers.getSigners();

        const token = await ethers.deployContract("MockERC20", [
            "SimpleORAM",
            "SORAM",
            18
        ]);

        const WrapperFactory = await ethers.getContractFactory("PrivateWrapper");
        const wrapper = await WrapperFactory.deploy(await token.getAddress());

        const wallets: HDNodeWallet[]  = [];
        for (let i = 0; i < 10; i++) {
            const provider = sapphire.wrap(new ethers.JsonRpcProvider(
                "http://localhost:8545",
            ));
            const wallet = sapphire.wrap(ethers.Wallet.createRandom(provider));
            await me.sendTransaction({
                to: wallet.address,
                value: ethers.parseEther("0.1"),
                data: "0x"
            })

            wallets.push(wallet);
        }

        await token.get(me.address, ethers.parseEther("1000"));
        await token.approve(await wrapper.getAddress(), ethers.MaxUint256);

        await wrapper.wrap(ethers.parseEther("1000"), me.address);

        const initialBalance = await wrapper.balanceOf(me.address);

        const expectedAmounts = [53543, 23425, 12323, 11111, 555555, 585843, 2948525, 67993, 22222, 99995];
        for (const [i, wallet] of wallets.entries()) {
            await wrapper.transfer(wallet.address, expectedAmounts[i]);
        }

        const actualAmounts: BigInt[] = [];
        let sum = 0n;
        for (const wallet of wallets) {
            const balance = await wrapper.connect(wallet).balanceOf(wallet.address);
            actualAmounts.push(balance);
            sum += balance;
        }

        expect(actualAmounts).to.deep.equal(expectedAmounts.map(n => BigInt(n)));
        expect(await wrapper.balanceOf(me.address)).to.equal(initialBalance - sum);
    }).timeout(0)
})