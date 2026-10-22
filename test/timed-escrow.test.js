const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("TimedEscrow", function () {
  async function deploy(window = 3600) {
    const [buyer, seller, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("TimedEscrow");
    const escrow = await Factory.deploy(seller.address, window);
    return { escrow, buyer, seller, other };
  }

  it("records the parties and starts awaiting a deposit", async function () {
    const { escrow, buyer, seller } = await deploy();
    expect(await escrow.buyer()).to.equal(buyer.address);
    expect(await escrow.seller()).to.equal(seller.address);
    expect(await escrow.status()).to.equal(0n);
  });

  it("accepts a buyer deposit and releases it to the seller", async function () {
    const { escrow, buyer, seller } = await deploy();
    const value = ethers.parseEther("1");
    await expect(escrow.connect(buyer).deposit({ value }))
      .to.emit(escrow, "Deposited").withArgs(buyer.address, value);
    await expect(escrow.connect(buyer).release())
      .to.emit(escrow, "PaymentReleased").withArgs(buyer.address, seller.address, value);
    expect(await escrow.status()).to.equal(2n);
    expect(await escrow.depositAmount()).to.equal(0n);
  });

  it("rejects deposits from non-buyers", async function () {
    const { escrow, other } = await deploy();
    await expect(escrow.connect(other).deposit({ value: 1 })).to.be.revertedWithCustomError(escrow, "Unauthorized");
  });

  it("refunds the buyer after the deadline", async function () {
    const { escrow, buyer } = await deploy(10);
    const value = ethers.parseEther("0.25");
    await escrow.connect(buyer).deposit({ value });
    await network.provider.send("evm_increaseTime", [11]);
    await network.provider.send("evm_mine");
    await expect(escrow.connect(buyer).refund()).to.emit(escrow, "Refunded").withArgs(buyer.address, value);
    expect(await escrow.status()).to.equal(3n);
  });
});
