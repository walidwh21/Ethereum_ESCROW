const hre = require("hardhat");

async function main() {
  const [buyer, seller] = await hre.ethers.getSigners();
  const refundWindow = 60 * 60; // one hour

  const Escrow = await hre.ethers.getContractFactory("TimedEscrow");
  const escrow = await Escrow.deploy(seller.address, refundWindow);
  await escrow.waitForDeployment();

  console.log("TimedEscrow address:", await escrow.getAddress());
  console.log("Buyer:", buyer.address);
  console.log("Seller:", seller.address);
  console.log("Refund deadline:", (await escrow.refundDeadline()).toString());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
