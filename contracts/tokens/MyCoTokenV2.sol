// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol"; // Context is imported to use _msgSender()
import "@openzeppelin/contracts/utils/Context.sol"; // Context is imported to use _msgSender()

import "./Taxable.sol";
import "./MyCoOnDexV1.sol";
import "hardhat/console.sol";

/// @custom:security-contact oluwafemi@mcontent.net
/**
 * @title MyCo Token V2 for MSeed Watch2Earn Platform
 * @notice For future upgrades, do not change MyCoTokenV2. Create a new
 * contract which implements MyCoTokenV2 and following the naming convention
 * MYCOTOKENVX, where X is the next version.
 */
contract MyCoTokenV2 is Taxable, Initializable, MyCoOnDexV1, PausableUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PRESIDENT_ROLE = keccak256("PRESIDENT_ROLE");
    bytes32 public constant EXCLUDED_ROLE = keccak256("EXCLUDED_ROLE");

    function initialize() public initializer {
        __ERC20_init("MYCO Token", "MYCO");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __Ownable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(PRESIDENT_ROLE, msg.sender);
        _grantRole(EXCLUDED_ROLE, msg.sender);
        _mint(msg.sender, 10_000_000_000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, msg.sender);
        _taxon();
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function enableTax() public onlyRole(GOVERNOR_ROLE) {
        _taxon();
    }

    function disableTax() public onlyRole(GOVERNOR_ROLE) {
        _taxoff();
    }

    function updateTax(uint256 newtax) public onlyRole(GOVERNOR_ROLE) {
        _updatetax(newtax);
    }

    function updateBurn(uint256 newburn) public onlyRole(GOVERNOR_ROLE) {
        _updateburntax(newburn);
    }

    function updateCcf(uint256 newtax) public onlyRole(GOVERNOR_ROLE) {
        _updateccftax(newtax);
    }

    function updateTaxDestination(address newdestination) public onlyRole(PRESIDENT_ROLE) {
        _updatetaxdestination(newdestination);
    }

    /**
     *
     * • The EXCLUDED_ROLE is for any wallet or contract that would be contradicted to tax to/from such as the deployer, the treasury, or a vesting contract.
     * • The GOVERNOR_ROLE can be a governance controlled contract to enable/disable and change the tax amount based on proposal results.
     * • The PRESIDENT_ROLE is not the GOVERNOR_ROLE because the address to change the destination address and tax amount is a target for an exploit.
     * • It is recommended that the DEFAULT_ADMIN_ROLE renounce either/both the PRESIDENT_ROLE and/or the GOVERNOR_ROLE and assign these to unconnected accounts.
     * • Once all roles are set up, it is recommended that the DEFAULT_ADMIN_ROLE add a Multisig admin and renounce the admin role as well as any unnecessary roles.
     * • `ccftax()` is deducted as tax for the CCF fund on every transfer
     * • `burntax()` is burned out of the circulating supply from every transfer
     * • Tax can be turned on or off. `ccftax()` and `burntax()` is not deducted from addresses with the role EXCLUDED_ROLE
     */
    function _transfer(
        address from,
        address to,
        uint256 amount // Overrides the _transfer() function to use an optional transfer tax.
    )
        internal
        virtual
        override(
            ERC20Upgradeable // Specifies only the ERC20Upgradeable contract for the override.
        )
        nonReentrant // Prevents re-entrancy attacks.
        whenNotPaused // Prevents transfers while paused.
    {
        if (hasRole(EXCLUDED_ROLE, from) || hasRole(EXCLUDED_ROLE, to) || !taxed()) {
            // If to/from a tax excluded address or if tax is off...
            super._transfer(from, to, amount); // Transfers 100% of amount to recipient.
        } else {
            // If not to/from a tax excluded address & tax is on...
            require(balanceOf(from) >= amount, "ERC20: transfer amount exceeds balance"); // Makes sure sender has the required token amount for the total.
            // If the above requirement is not met, then it is possible that the sender could pay the tax but not the recipient, which is bad...
            super._burn(from, (amount * burnTax()) / 10000); // Transfers tax to the tax destination address.
            super._transfer(from, taxDestination(), (amount * ccfTax()) / 10000); // Transfers tax to the tax destination address.
            super._transfer(from, to, (amount * (10000 - theTax())) / 10000); // Transfers the remainder to the recipient.
        }
    }

    //to receive BNB from uniswapV2Router when swapping
    receive() external payable {}
}
