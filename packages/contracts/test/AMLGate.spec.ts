import { expect } from "chai";
import {ethers, getChainId} from "hardhat";

describe('AMLGate', async () => {
    const loadAmlGateFixture = async () => {
        const [me] = await ethers.getSigners();

        const mockMessageBus = await ethers.deployContract("MockCelerMessageBus");
        const crossChainVault = await ethers.deployContract("CrossChainVault");
        const crossChainVaultApp = await ethers.deployContract("CrossChainVaultApp", [
            await crossChainVault.getAddress(),
            await mockMessageBus.getAddress(),
        ]);

        const multichainEndpoint = await ethers.deployContract("MultichainEndpoint", [
            await crossChainVaultApp.getAddress(),
            true
        ]);

        await crossChainVaultApp.setActualEndpoint(await multichainEndpoint.getAddress());

        const privateWrapperFactory = await ethers.deployContract("PrivateWrapperFactory");
        const complianceManager = await ethers.deployContract("ComplianceManager");

        const sapphireEndpoint = await ethers.deployContract("SapphireEndpoint", [
            await privateWrapperFactory.getAddress(),
            await crossChainVaultApp.getAddress(),
            await complianceManager.getAddress(),
            ethers.randomBytes(32),
            true
        ]);

        const amlGate = await ethers.deployContract("AMLGate", [await multichainEndpoint.getAddress()]);
        await amlGate.toggleAmlVerifier(me.address);

        const mockErc20 = await ethers.deployContract("MockERC20", [
            "Test",
            "TST",
            18
        ]);

        await crossChainVault.setAllowedAssets([{
            asset: await mockErc20.getAddress(),
            isAllowed: true
        }]);

        await multichainEndpoint.setTrustedForwarder(await amlGate.getAddress());
        await multichainEndpoint.toggleAllowedSender(await amlGate.getAddress());
        await multichainEndpoint.setConnectedEndpoints([
            {
                chainId: 0,
                contractAddress: await multichainEndpoint.getAddress()
            },
            {
                chainId: await multichainEndpoint.SAPPHIRE_CHAINID(),
                contractAddress: await sapphireEndpoint.getAddress()
            }
        ]);

        await multichainEndpoint.setFixedFee([
            {
                fee: {
                    settlementCost: 1,
                    settlementCostInLocalCurrency: 1
                },
                chainId: 0,
            }
        ])

        const amt = ethers.parseEther("10000");
        await mockErc20.get(me.address, amt);

        const encryptedParams = await sapphireEndpoint.prepareEncryptedParams({
            nonce: ethers.randomBytes(32),
            swapPath: [],
            outputs: [{
                to: me.address,
                extra: 0,
                chainId: await getChainId(),
                kind: 2,
                amount: amt
            }]
        });

        const payload = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "bytes"], [
            encryptedParams.keyIndex,
            encryptedParams.encoded
        ]);

        return { amlGate, multichainEndpoint, mockErc20, sapphireEndpoint, encryptedParams: payload };
    };

    it("prohibit direct calls", async () => {
        const fixture = await loadAmlGateFixture();
        await expect(
            fixture.multichainEndpoint
                .proxyPass
                .staticCall(
                    await fixture.mockErc20.getAddress(),
                    ethers.parseEther("10000"),
                    fixture.encryptedParams
                )
        ).to.revertedWith("Sender is not allowed");
    }).timeout(0)

    it("deposit initiated", async () => {
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));
        await expect(
            fixture.amlGate
                .proxyPass(
                    await fixture.mockErc20.getAddress(),
                    ethers.parseEther("10000"),
                    fixture.encryptedParams,
                    {
                        value: ethers.parseEther("1")
                    }
                )
        ).to.emit(fixture.amlGate, "DepositInitiated").withArgs(0)
    }).timeout(0)

    it("approve initiated deposit", async () => {
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));
        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )

        await expect(
            fixture.amlGate
                .approveDeposit(
                    0
                )
        ).to.emit(fixture.amlGate, "DepositApproved").withArgs(0)
    }).timeout(0)

    it("can't approve again", async () => {
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));
        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )

        await fixture.amlGate
            .approveDeposit(
                0
            );

        await expect(fixture.amlGate.approveDeposit.staticCall(0)).to.revertedWith("Not allowed");
    }).timeout(0)

    it("refund", async () => {
        const [me] = await ethers.getSigners();
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));

        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )
        const balance1 = await fixture.mockErc20.balanceOf(me.address);
        expect(balance1).to.eq(0n);

        await expect(
            fixture.amlGate
                .refund(
                    0
                )
        ).to.emit(fixture.amlGate, "DepositRefunded").withArgs(0)

        const balance2 = await fixture.mockErc20.balanceOf(me.address);

        const diff1 = balance2 - balance1;
        expect(diff1).to.eq(ethers.parseEther("10000"));
    }).timeout(0)

    it("can't refund twice", async () => {
        const [me] = await ethers.getSigners();
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));

        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )

        await fixture.amlGate.refund(0);
        await expect(
            fixture.amlGate
                .refund.staticCall(
                    0
                )
        ).to.revertedWith("Not allowed");
    }).timeout(0)

    it("can't refund after approval", async () => {
        const [me] = await ethers.getSigners();
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));

        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )

        await fixture.amlGate.approveDeposit(0);
        await expect(
            fixture.amlGate
                .refund.staticCall(
                0
            )
        ).to.revertedWith("Not allowed");
    }).timeout(0)

    it("can't approve after refund", async () => {
        const [me] = await ethers.getSigners();
        const fixture = await loadAmlGateFixture();

        await fixture.mockErc20.approve(await fixture.amlGate.getAddress(), ethers.parseEther("10000"));

        await fixture.amlGate
            .proxyPass(
                await fixture.mockErc20.getAddress(),
                ethers.parseEther("10000"),
                fixture.encryptedParams,
                {
                    value: ethers.parseEther("1")
                }
            )

        await fixture.amlGate.refund(0);
        await expect(
            fixture.amlGate
                .approveDeposit.staticCall(
                0
            )
        ).to.revertedWith("Not allowed");
    }).timeout(0)
})