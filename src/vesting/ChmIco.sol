// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChmBaseVesting} from "./ChmBaseVesting.sol";
import {Stage, User} from "../utils/Structs.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IcoState, Currency} from "../utils/Enums.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmIco is ReentrancyGuard, ChmBaseVesting {
    error ZeroAddressNotAllowed();
    error InvalidIcoState(IcoState state);
    error InvalidBuyer();
    error InsufficientPayment();
    error UnsupportedCurrency();
    error InsufficientTokensAvailable();
    error NoRefundAvailable();

    event TokensPurchased(address indexed buyer, uint256 amount, Currency currency, uint256 payment);
    event IcoSucceeded();
    event IcoFailed();
    event ProgressedStage(IcoState newState);
    event RefundIssued(address indexed refundee, uint256 amount, Currency currency);

    Stage[] private _stages;

    IcoState private _icoState;

    mapping(address => bool) private _whitelist;

    uint64 public constant MINIMUM_RAISE = 1_000_000_000_000; // 1 trillion microUSDT = 1 million USDT
    uint64 private _raisedAmount; // Total amount raised in microUSDT (6 decimals)
    uint32 private _chmSold; // Total CHM sold (no decimals)

    address public constant CHAINLINK_USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
    AggregatorV3Interface private usdtEthPriceFeed;
    uint8 public chainlinkDecimals;

    IERC20 public immutable USDT_TOKEN;
    IERC20 public immutable USDC_TOKEN;
    IWETH public immutable WETH_TOKEN;

    address private immutable _TREASURY;
    ChmBaseVesting public immutable TEAM_VESTING;
    ChmBaseVesting public immutable MARKETING_VESTING;

    constructor(
        address accessControlManager_,
        address chmToken_,
        address chmIcoGovernanceToken_,
        address usdtToken_,
        address usdcToken_,
        address wethToken_,
        address treasury_,
        address teamVesting_,
        address marketingVesting_
    ) ChmBaseVesting(accessControlManager_, chmToken_, chmIcoGovernanceToken_, 2 days, 0, 30 days) {
        if (usdtToken_ == address(0) || usdcToken_ == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        USDT_TOKEN = IERC20(usdtToken_);
        USDC_TOKEN = IERC20(usdcToken_);
        WETH_TOKEN = IWETH(wethToken_);
        _TREASURY = treasury_;
        TEAM_VESTING = ChmBaseVesting(teamVesting_);
        MARKETING_VESTING = ChmBaseVesting(marketingVesting_);
        // TODO: Decide how long _stages should last
        // TODO: Do some modelling to decide on stage details
        _stages.push(Stage(1_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(2_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(3_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(4_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(5_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(7_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(10_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(15_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(20_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _stages.push(Stage(30_000_000, uint32(block.timestamp), 30 days, 1_000_000));
        _icoState = IcoState.NotStarted;
        usdtEthPriceFeed = AggregatorV3Interface(CHAINLINK_USDT_ETH_FEED);
        chainlinkDecimals = usdtEthPriceFeed.decimals();
    }

    function startIco() external restricted {
        if (_icoState != IcoState.NotStarted) {
            revert InvalidIcoState(_icoState);
        }
        _icoState = IcoState.Stage1;
        _stages[0].startTime = uint32(block.timestamp);
    }

    modifier icoActive() {
        if (_icoState == IcoState.NotStarted || _icoState == IcoState.Succeeded || _icoState == IcoState.Failed) {
            revert InvalidIcoState(_icoState);
        }
        _;
    }

    modifier allowedToPurchase(address buyer) {
        if (_icoState == IcoState.Private) {
            if (!_whitelist[buyer]) {
                revert InvalidIcoState(_icoState);
            }
        } else {
            uint256 icoState = uint256(_icoState);
            uint256 firstPublicStage = uint256(IcoState.Stage1);
            uint256 lastPublicStage = uint256(IcoState.Stage10);
            if (icoState < firstPublicStage || icoState > lastPublicStage) {
                revert InvalidIcoState(_icoState);
            }
        }
        _;
    }

    function getLatestUsdtEthPrice() public view returns (uint256) {
        (, int256 price,,,) = usdtEthPriceFeed.latestRoundData();
        return uint256(price);
    }

    function purchaseTokens(
        address buyer,
        uint96[2] calldata purchaseDetails,
        Currency currency,
        IcoState expectedState
    ) external payable nonReentrant icoActive allowedToPurchase(buyer) {
        uint96 expectedTokens = purchaseDetails[0];
        uint96 payment = purchaseDetails[1];
        // Checks
        if (_icoState != expectedState) {
            revert InvalidIcoState(_icoState);
        }
        Stage memory currentStage = _stages[uint256(_icoState)];
        if (currentStage.tokensAvailable < expectedTokens) {
            revert InsufficientTokensAvailable();
        }
        uint96 cost;
        if (currency == Currency.USDT) {
            cost = uint96(expectedTokens * currentStage.price);
            if (USDT_TOKEN.allowance(buyer, address(this)) < cost) {
                revert InsufficientPayment();
            }
            _userVesting[buyer].usdtOwed += cost;
        } else if (currency == Currency.USDC) {
            cost = uint96(expectedTokens * currentStage.price);
            if (USDC_TOKEN.allowance(buyer, address(this)) < cost) {
                revert InsufficientPayment();
            }
            _userVesting[buyer].usdcOwed += cost;
        } else if (currency == Currency.ETH) {
            cost = uint96((expectedTokens * currentStage.price * getLatestUsdtEthPrice()) / (10 ** chainlinkDecimals));
            if (msg.value < cost) {
                revert InsufficientPayment();
            }
            _userVesting[buyer].ethOwed += cost;
        } else {
            revert UnsupportedCurrency();
        }
        if (payment < cost) {
            revert InsufficientPayment();
        }

        // Effects
        _userVesting[buyer].chmOwed += expectedTokens;
        currentStage.tokensAvailable -= expectedTokens;
        _raisedAmount += uint64(expectedTokens * currentStage.price);
        _chmSold += uint32(expectedTokens);
        if (currentStage.tokensAvailable == 0 || block.timestamp >= currentStage.startTime + currentStage.duration) {
            _progressStage();
        }

        // Interactions
        if (!CHM_ICO_GOVERNANCE_TOKEN.approve(buyer, expectedTokens)) {
            revert TransferFailed();
        }
        uint256 ethToRefund = 0;
        if (msg.value > 0) {
            WETH_TOKEN.deposit{value: msg.value}();
        }
        if (currency == Currency.ETH) {
            ethToRefund = msg.value - cost;
        } else {
            ethToRefund = msg.value;
            if (currency == Currency.USDT) {
                USDT_TOKEN.safeTransferFrom(buyer, address(this), cost);
            } else if (currency == Currency.USDC) {
                USDC_TOKEN.safeTransferFrom(buyer, address(this), cost);
            }
        }
        if (ethToRefund > 0) {
            if (!WETH_TOKEN.approve(buyer, ethToRefund)) {
                revert TransferFailed();
            }
        }

        emit TokensPurchased(buyer, expectedTokens, currency, payment);
    }

    function progressStage() external nonReentrant restricted icoActive {
        _progressStage();
    }

    function endIco() external nonReentrant restricted {
        _endIco();
    }

    function _endIco() internal icoActive {
        if (_raisedAmount >= MINIMUM_RAISE) {
            _icoSucceeded();
        } else {
            _icoFailed();
        }
    }

    function _icoSucceeded() internal vestingNotStarted {
        _icoState = IcoState.Succeeded;
        // Burn unsold tokens
        if (CHM_TOKEN.balanceOf(address(this)) > _chmSold) {
            CHM_TOKEN.burn(CHM_TOKEN.balanceOf(address(this)) - _chmSold);
        }
        TEAM_VESTING.startVesting();
        MARKETING_VESTING.startVesting();
        startVesting();
        // Transfer all raised funds to treasury
        uint256 etherBalance = WETH_TOKEN.balanceOf(address(this));
        if (etherBalance > 0) {
            WETH_TOKEN.safeTransfer(_TREASURY, etherBalance);
        }
        uint256 usdtBalance = USDT_TOKEN.balanceOf(address(this));
        if (usdtBalance > 0) {
            USDT_TOKEN.safeTransfer(_TREASURY, usdtBalance);
        }
        uint256 usdcBalance = USDC_TOKEN.balanceOf(address(this));
        if (usdcBalance > 0) {
            USDC_TOKEN.safeTransfer(_TREASURY, usdcBalance);
        }
        emit IcoSucceeded();
    }

    function _icoFailed() internal {
        _icoState = IcoState.Failed;
        CHM_TOKEN.burn(CHM_TOKEN.balanceOf(address(this)));
        emit IcoFailed();
    }

    function _progressStage() internal {
        if (_icoState == IcoState.NotStarted) {
            revert InvalidIcoState(_icoState);
        }
        if (_icoState == IcoState.Stage11) {
            _endIco();
            return;
        }
        uint96 tokensAvailable = _stages[uint256(_icoState)].tokensAvailable;
        uint8 newState = uint8(_icoState) + 1;
        if (tokensAvailable > 0) {
            _stages[newState].tokensAvailable += tokensAvailable;
        }
        _stages[newState].startTime = uint32(block.timestamp);
        _icoState = IcoState(newState);

        emit ProgressedStage(_icoState);
    }

    // External function to refund ETH to a buyer
    function refundEth(address refundee) external nonReentrant {
        // Checks
        User memory user = _userVesting[refundee];
        if (user.ethOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.ethOwed;
        _userVesting[refundee].ethOwed = 0;

        // Interactions
        WETH_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.ETH);
    }

    // External function to refund USDT to a buyer
    function refundUdst(address refundee) external nonReentrant {
        // Checks
        User memory user = _userVesting[refundee];
        if (user.usdtOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.usdtOwed;
        _userVesting[refundee].usdtOwed = 0;

        // Interactions
        USDT_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.USDT);
    }

    // External function to refund USDC to a buyer
    function refundUsdc(address refundee) external nonReentrant {
        // Checks
        User memory user = _userVesting[refundee];
        if (user.usdcOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.usdcOwed;
        _userVesting[refundee].usdcOwed = 0;

        // Interactions
        USDC_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.USDC);
    }

    function getIcoState() external view returns (IcoState) {
        return _icoState;
    }

    function getStageDetails() external view returns (Stage memory) {
        return _stages[uint256(_icoState)];
    }
}
