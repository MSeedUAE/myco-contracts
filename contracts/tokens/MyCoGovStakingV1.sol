// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./MyCoGovV1.sol";

contract MyCoStakingGovV1 is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    uint256 constant MINIMUM_DURATION = 1; //1 week, minimum staking
    uint256 constant MAXIMUM_DURATION = 208; //208 weeks, maximum week staking
    uint256 constant MINIMUM_STAKE = 1000; //Minimum in user account to stake
    uint256 constant MINIMUM_ADDITIONAL_STAKE = 100; //Minimum  increase stake

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public myCo;
    address public myCoGov;
    MyCoGovV1 public myGovToken;

    struct Stake {
        uint256 amount;
        uint256 out;
        uint256 duration; //in weeks
        uint256 start;
        uint256 end;
    }

    mapping(address => Stake) public stakes;

    function initialize(address _myCo, address _myCoGov) public initializer {
        require(_myCo != address(0x0), "MyCoStakingGovV1: Invalid myco");

        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        myCo = _myCo;
        myCoGov = _myCoGov;
        myGovToken = MyCoGovV1(_myCoGov);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev address(this) must have minter role on MyCoGov contract
     */
    function stake(
        uint256 amountin,
        uint256 duration
    ) public whenNotPaused nonReentrant returns (uint256 amountout) {
        require(amountin >= 1, "MyCoStakingGovV1: invalid amount");
        require(duration >= 1, "MyCoStakingGovV1: invalid week");
        require(stakes[_msgSender()].amount == 0, "MyCoStakingGovV1: stake exist");

        bool sent = ERC20Upgradeable(myCo).transferFrom(_msgSender(), address(this), amountin);

        require(sent, "MyCoStakingGovV1: error");

        uint256 out = _calcOut(amountin, duration);

        myGovToken.mint(_msgSender(), out);

        stakes[_msgSender()] = Stake(
            amountin,
            out,
            duration,
            block.timestamp,
            block.timestamp.add(duration.mul(1 weeks))
        );

        return out;
    }

    function increaseStakeBy(
        uint256 amount
    ) public whenNotPaused nonReentrant returns (bool status) {
        require(amount > MINIMUM_ADDITIONAL_STAKE, "MyCoStakingGovV1: Invalid amount");
        require(stakes[_msgSender()].amount > 0, "MyCoStakingGovV1: Stake 404");

        Stake memory _stake = stakes[_msgSender()];

        bool sent = ERC20Upgradeable(myCo).transferFrom(_msgSender(), address(this), amount);

        require(sent, "MyCoStakingGovV1: error");

        uint256 oldOut = _stake.out;
        uint256 out = _calcOut(_stake.amount.add(amount), _stake.duration);

        _stake.out = out;
        _stake.amount = _stake.amount.add(amount);

        //This should never happen, but we its good to check
        assert(out > oldOut);

        myGovToken.mint(_msgSender(), out.sub(oldOut));

        return true;
    }

    function extendLockTimeBy(
        uint256 duration
    ) public whenNotPaused nonReentrant returns (bool status) {
        require(duration >= 1, "MyCoStakingGovV1: Invalid duration");
        require(stakes[_msgSender()].amount > 0, "MyCoStakingGovV1: Stake 404");

        Stake memory _stake = stakes[_msgSender()];

        require(
            duration.add(_stake.duration) <= MAXIMUM_DURATION,
            "MyCoStakingGovV1: Max duration"
        );

        uint256 oldOut = _stake.out;
        uint256 out = _calcOut(_stake.amount, _stake.duration.add(duration));

        _stake.out = out;
        _stake.end = _stake.end.add(duration.mul(1 weeks));

        //This should never happen, but we its good to check
        assert(out > oldOut);

        myGovToken.mint(_msgSender(), out.sub(oldOut));

        return true;
    }

    function calcOut(uint256 amountin, uint256 duration) public pure returns (uint256 amountout) {
        return _calcOut(amountin, duration);
    }

    function claim() public whenNotPaused nonReentrant returns (bool claimable, uint256 out) {
        require(stakes[_msgSender()].amount > 0, "MyCoStakingGovV1: Stake 404");

        Stake memory _stake = stakes[_msgSender()];

        if (block.timestamp > _stake.end) {
            uint256 govTokenBalance = myGovToken.balanceOf(_msgSender());

            myGovToken.burn(govTokenBalance);

            ERC20Upgradeable(myCo).transfer(_msgSender(), _stake.amount);

            delete stakes[_msgSender()];

            return (true, _stake.out);
        }

        return (false, 0);
    }

    /**
     * Lock time Ti, Lock max time Tm = 208 weeks. Amount of MyCo token to lock up = a
     *
     * vPow = a(t/tmax)
     */
    function _calcOut(uint256 _amountin, uint256 _duration) internal pure returns (uint256) {
        require(_amountin <= MINIMUM_STAKE, "MyCoStakingGovV1: Max week");
        require(_duration <= MAXIMUM_DURATION, "MyCoStakingGovV1: Max week");
        require(_duration >= MINIMUM_DURATION, "MyCoStakingGovV1: Min week");

        return _amountin.mul(_duration.div(MAXIMUM_DURATION));
    }

    receive() external payable {}
}
