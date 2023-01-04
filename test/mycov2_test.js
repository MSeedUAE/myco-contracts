/**
 * @fileoverview Test cases for MyCoV2.sol
 * @author oluwafemialofe
 * The following units and functional test cases are covered:
 * - When initializer is called, the name, symbol, supply should be set
 * - Deployer should own initial token supply
 * - Deployer should own DEFAULT_ADMIN_ROLE, PAUSER_ROLE, MINTER_ROLE, GOVERNOR_ROLE, PRESIDENT_ROLE, EXCLUDED_ROLE & MINER_ROLE
 * - Deployer should be able to mint tokens
 * - Deployer should be able to pause and unpause
 * - When paused, transfer should be disabled
 * - When a user is excluded, they should be able to transfer exact tokens
 * - Can GOVERNOR_ROLE user update overall tax
 * - Can GOVERNOR_ROLE user update ccf tax
 * - Can GOVERNOR_ROLE user update ccf burn
 * - Can GOVERNOR_ROLE user update ccc tax destination
 * - Can GOVERNOR_ROLE user disable tax
 * - Can GOVERNOR_ROLE user enable tax
 * - Transfering 1000 MyCo tokens should burn _burntax% of tokens, transfer _ccftax% to _taxdestination and transfer the rest to the recipient, should be mathematically accurate.
 * - Transfering token to a excluded account should not burn tokens or charge tax
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyCoTokenV2", function() {
	before(async function() {
		const [
			deployer,
			accountA,
			accountB,
			accountC,
			accountD
		] = await ethers.getSigners();

		this.deployer = deployer;
		this.accountA = accountA;
		this.accountB = accountB;
		this.accountC = accountC;
		this.accountD = accountD;

		this.MyCoTokenV2 = await ethers.getContractFactory("MyCoTokenV2");
		this.myco = await this.MyCoTokenV2.deploy();
		await this.myco.deployed();

		await this.myco.initialize();

		//Exclude tax destination from tax
		await this.myco.grantRole(
			ethers.utils.formatBytes32String("EXCLUDED_ROLE"),
			this.accountD.address
		);
	});

	it("When initializer is called, the name, symbol, supply should be set", async function() {
		expect(await this.myco.name()).to.equal("MYCO Token");
		expect(await this.myco.symbol()).to.equal("MYCO");
		expect(await this.myco.totalSupply()).to.equal(
			ethers.utils.parseEther("10000000000")
		);
	});

	it("Deployer should own initial token supply", async function() {
		expect(await this.myco.balanceOf(this.deployer.address)).to.equal(
			ethers.utils.parseEther("10000000000")
		);
	});

	it("Deployer should own DEFAULT_ADMIN_ROLE, PAUSER_ROLE, MINTER_ROLE, GOVERNOR_ROLE, PRESIDENT_ROLE, EXCLUDED_ROLE & MINER_ROLE", async function() {
		expect(
			await this.myco.hasRole(
				await this.myco.DEFAULT_ADMIN_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
		expect(
			await this.myco.hasRole(
				await this.myco.PAUSER_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
		expect(
			await this.myco.hasRole(
				await this.myco.MINTER_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
		expect(
			await this.myco.hasRole(
				await this.myco.GOVERNOR_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
		expect(
			await this.myco.hasRole(
				await this.myco.PRESIDENT_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
		expect(
			await this.myco.hasRole(
				await this.myco.EXCLUDED_ROLE(),
				this.deployer.address
			)
		).to.equal(true);
	});

	it("Deployer should be able to mint tokens", async function() {
		await this.myco.mint(
			this.accountA.address,
			ethers.utils.parseEther("200")
		);
		expect(await this.myco.balanceOf(this.accountA.address)).to.equal(
			ethers.utils.parseEther("200")
		);
	});

	it("Deployer should be able to pause and unpause", async function() {
		await this.myco.pause();
		expect(await this.myco.paused()).to.equal(true);
		await this.myco.unpause();
		expect(await this.myco.paused()).to.equal(false);
	});

	it("When paused, transfer should be disabled", async function() {
		await this.myco.pause();
		await expect(
			this.myco.transfer(
				this.accountB.address,
				ethers.utils.parseEther("1")
			)
		).to.be.revertedWith("Pausable: paused");
	});

	it("tax enabled should be true", async function() {
		expect(await this.myco.taxed()).to.equal(true);
	});

	it("When a user is excluded, they should be able to transfer exact tokens", async function() {
		await this.myco.unpause();

		await this.myco.grantRole(
			await this.myco.EXCLUDED_ROLE(),
			this.accountB.address
		);

		expect(
			await this.myco.hasRole(
				await this.myco.EXCLUDED_ROLE(),
				this.accountB.address
			)
		).to.equal(true);

		await this.myco
			.connect(this.accountA)
			.transfer(this.accountB.address, ethers.utils.parseEther("150"));
		expect(await this.myco.balanceOf(this.accountB.address)).to.equal(
			ethers.utils.parseEther("150")
		);
	});

	it("Can GOVERNOR_ROLE user update overall tax", async function() {
		await this.myco.connect(this.deployer).updateTax(1000);
		expect(await this.myco.theTax()).to.equal(1000);
	});

	//Update ccf to 5%
	it("Can GOVERNOR_ROLE user update ccf tax", async function() {
		await this.myco.connect(this.deployer).updateCcf(500);
		expect(await this.myco.ccfTax()).to.equal(500);
	});

	//Update burn to 5%
	it("Can GOVERNOR_ROLE user update burn tax", async function() {
		await this.myco.connect(this.deployer).updateBurn(500);
		expect(await this.myco.burnTax()).to.equal(500);
	});

	it("Can update tax destination", async function() {
		await this.myco
			.connect(this.deployer)
			.updateTaxDestination(this.accountD.address);
		expect(await this.myco.taxDestination()).to.equal(
			this.accountD.address
		);
	});

	it("Transfering 100 tokens should result in 5 tokens being burned and 5 sent to cff destination address", async function() {
		//Revoke EXCLUDED_ROLE from accountB
		await this.myco.revokeRole(
			await this.myco.EXCLUDED_ROLE(),
			this.accountB.address
		);

		/*
		 * State before transfer
		 * adddressA: 50
		 * addressB: 150
		 * addressC: 0
		 */
		await this.myco
			.connect(this.accountB)
			.transfer(this.accountC.address, ethers.utils.parseEther("100"));

		expect(await this.myco.balanceOf(this.accountC.address)).to.equal(
			ethers.utils.parseEther("90")
		);
		expect(await this.myco.balanceOf(this.accountD.address)).to.equal(
			ethers.utils.parseEther("5")
		);
		expect(await this.myco.balanceOf(this.accountB.address)).to.equal(
			ethers.utils.parseEther("50")
		);
	});

	it("It should send exact token when is disabled", async function() {
		await this.myco.connect(this.deployer).disableTax();

		expect(await this.myco.taxed()).to.equal(false);

		await this.myco
			.connect(this.accountB)
			.transfer(this.accountC.address, ethers.utils.parseEther("50"));
		expect(await this.myco.balanceOf(this.accountC.address)).to.equal(
			ethers.utils.parseEther("140")
		);

		expect(await this.myco.balanceOf(this.accountD.address)).to.equal(
			ethers.utils.parseEther("5")
		);

		expect(await this.myco.balanceOf(this.accountB.address)).to.equal(
			ethers.utils.parseEther("0")
		);
	});
});
