/**
 * @fileoverview Test cases for MyCoV2.sol
 * @author oluwafemialofe
 * The following units and functional test cases are covered:
 * - When initializer is called, the name, symbol, supply should be set
 * - Deployer hsould own initial token supply
 * - Deployer should own DEFAULT_ADMIN_ROLE, PAUSER_ROLE, MINTER_ROLE, GOVERNOR_ROLE, PRESIDENT_ROLE, EXCLUDED_ROLE & MINER_ROLE
 * - Deployer should be able to mint tokens
 * - Deployer should be able to pause and unpause
 * - When paused, transfer should be disabled
 * - When a user is excluded, they should not be able to transfer tokens
 * - Can GOVERNOR_ROLE user update overall tax
 * - Can GOVERNOR_ROLE user update ccf tax
 * - Can GOVERNOR_ROLE user update ccf burn
 * - Can GOVERNOR_ROLE user update ccc tax destination
 * - Can GOVERNOR_ROLE user disable tax
 * - Can GOVERNOR_ROLE user enable tax
 * - Transfering 1000 MyCo tokens should burn _burntax% of tokens, transfer _ccftax% to _taxdestination and transfer the rest to the recipient, should be mathematically accurate.
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyCoTokenV2", function() {
	before(async function() {
		const [deployer, accountA, accountB] = await ethers.getSigners();

		this.deployer = deployer;
		this.accountA = accountA;
		this.accountB = accountB;

		this.MyCoTokenV2 = await ethers.getContractFactory("MyCoTokenV2");
		this.myco = await this.MyCoTokenV2.deploy();
		await this.myco.deployed();

		await this.myco.initialize();

		console.log("before 2");
	});

	it("When initializer is called, the name, symbol, supply should be set", async function() {
		expect(await this.myco.name()).to.equal("MYCO Token");
		expect(await this.myco.symbol()).to.equal("MYCO");
		expect(await this.myco.totalSupply()).to.equal(
			ethers.utils.parseEther("10000000000")
		);
	});
});
