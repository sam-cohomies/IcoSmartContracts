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

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmIco is ReentrancyGuard, ChmBaseVesting {
    error ZeroAddressNotAllowed();
    error InvalidIcoState(IcoState state);
    error InsufficientPayment();
    error UnsupportedCurrency();
    error InsufficientTokensAvailable();
    error NoRefundAvailable();

    event TokensPurchased(address indexed buyer, uint256 amount, Currency currency, uint256 payment);
    event IcoSucceeded();
    event IcoFailed();
    event ProgressedStage(IcoState newState);
    event RefundIssued(address indexed refundee, uint256 amount, Currency currency);

    enum IcoState {
        Stage1,
        Stage2,
        Stage3,
        Stage4,
        Stage5,
        Stage6,
        Stage7,
        Stage8,
        Stage9,
        Stage10,
        Stage11,
        NotStarted,
        Succeeded,
        Failed
    }

    enum Currency {
        USDT,
        USDC,
        ETH
    }

    Stage[] private stages;

    IcoState private icoState;

    uint64 public constant MINIMUM_RAISE = 1_000_000_000_000; // 1 trillion microUSDT = 1 million USDT
    uint64 private raisedAmount; // Total amount raised in microUSDT (6 decimals)
    uint32 private chmSold; // Total CHM sold (no decimals)

    address public constant CHAINLINK_USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
    AggregatorV3Interface private usdtEthPriceFeed;
    uint8 public chainlinkDecimals;

    IERC20 public immutable USDT_TOKEN;
    IERC20 public immutable USDC_TOKEN;
    IWETH public immutable WETH_TOKEN;

    address private immutable TREASURY;
    ChmBaseVesting public immutable TEAM_VESTING;
    ChmBaseVesting public immutable MARKETING_VESTING;

    constructor(
        address _accessControlManager,
        address _chmToken,
        address _usdtToken,
        address _usdcToken,
        address _wethToken,
        address _treasury,
        address _teamVesting,
        address _marketingVesting
    ) ChmBaseVesting(_accessControlManager, _chmToken, 2 days, 0, 30 days) {
        if (_usdtToken == address(0) || _usdcToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        USDT_TOKEN = IERC20(_usdtToken);
        USDC_TOKEN = IERC20(_usdcToken);
        WETH_TOKEN = IWETH(_wethToken);
        TREASURY = _treasury;
        TEAM_VESTING = ChmBaseVesting(_teamVesting);
        MARKETING_VESTING = ChmBaseVesting(_marketingVesting);
        // TODO: Decide how long stages should last
        // TODO: Do some modelling to decide on stage details
        stages.push(Stage(25_000_000, 3_500, 30 days, block.timestamp));
        stages.push(Stage(35_000_000, 3_900, 30 days, block.timestamp));
        stages.push(Stage(50_000_000, 4_400, 30 days, block.timestamp));
        stages.push(Stage(65_000_000, 4_900, 30 days, block.timestamp));
        stages.push(Stage(80_000_000, 5_500, 30 days, block.timestamp));
        stages.push(Stage(95_000_000, 6_200, 30 days, block.timestamp));
        stages.push(Stage(110_000_000, 6_900, 30 days, block.timestamp));
        stages.push(Stage(115_000_000, 7_700, 30 days, block.timestamp));
        stages.push(Stage(130_000_000, 8_500, 30 days, block.timestamp));
        stages.push(Stage(145_000_000, 9_400, 30 days, block.timestamp));
        stages.push(Stage(150_000_000, 10_400, 30 days, block.timestamp));
        icoState = IcoState.NotStarted;
        usdtEthPriceFeed = AggregatorV3Interface(CHAINLINK_USDT_ETH_FEED);
        chainlinkDecimals = usdtEthPriceFeed.decimals();
    }

    function startIco() external restricted {
        if (icoState != IcoState.NotStarted) {
            revert InvalidIcoState(icoState);
        }
        icoState = IcoState.Stage1;
        stages[0].startTime = block.timestamp;
    }

    modifier icoActive() {
        if (icoState == IcoState.NotStarted || icoState == IcoState.Succeeded || icoState == IcoState.Failed) {
            revert InvalidIcoState(icoState);
        }
        _;
    }

    function getLatestUsdtEthPrice() public view returns (uint256) {
        (, int256 price,,,) = usdtEthPriceFeed.latestRoundData();
        return uint256(price);
    }

    function purchaseTokens(
        address buyer,
        uint128 expectedTokens,
        Currency currency,
        uint128 payment,
        IcoState expectedState
    ) external payable nonReentrant icoActive {
        // Checks
        if (icoState != expectedState) {
            revert InvalidIcoState(icoState);
        }
        Stage memory currentStage = stages[uint256(icoState)];
        if (currentStage.tokensAvailable < expectedTokens) {
            revert InsufficientTokensAvailable();
        }
        uint256 cost;
        if (currency == Currency.USDT) {
            cost = expectedTokens * currentStage.price;
            if (USDT_TOKEN.allowance(buyer, address(this)) < cost) {
                revert InsufficientPayment();
            }
            userVesting[buyer].usdtOwed += payment;
        } else if (currency == Currency.USDC) {
            cost = expectedTokens * currentStage.price;
            if (USDC_TOKEN.allowance(buyer, address(this)) < cost) {
                revert InsufficientPayment();
            }
            userVesting[buyer].usdcOwed += payment;
        } else if (currency == Currency.ETH) {
            cost = (expectedTokens * currentStage.price * getLatestUsdtEthPrice()) / (10 ** chainlinkDecimals);
            if (msg.value < cost) {
                revert InsufficientPayment();
            }
            userVesting[buyer].ethOwed += payment;
        } else {
            revert UnsupportedCurrency();
        }
        if (payment < cost) {
            revert InsufficientPayment();
        }

        // Effects
        userVesting[buyer].chmOwed += expectedTokens;
        currentStage.tokensAvailable -= expectedTokens;
        raisedAmount += uint64(expectedTokens * currentStage.price);
        chmSold += uint32(expectedTokens);

        if (currentStage.tokensAvailable == 0 || block.timestamp >= currentStage.startTime + currentStage.duration) {
            _progressStage();
        }

        // Interactions
        uint256 ethToRefund = 0;
        if (msg.value > 0) {
            WETH_TOKEN.deposit{value: msg.value}();
        }
        if (currency == Currency.ETH) {
            ethToRefund = msg.value - cost;
        } else {
            ethToRefund = msg.value;
            if (currency == Currency.USDT) {
                USDT_TOKEN.safeTransferFrom(buyer, address(this), payment);
            } else if (currency == Currency.USDC) {
                USDC_TOKEN.safeTransferFrom(buyer, address(this), payment);
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
        if (raisedAmount >= MINIMUM_RAISE) {
            _icoSucceeded();
        } else {
            _icoFailed();
        }
    }

    function _icoSucceeded() internal vestingNotStarted {
        icoState = IcoState.Succeeded;
        // Burn unsold tokens
        if (CHM_TOKEN.balanceOf(address(this)) > chmSold) {
            CHM_TOKEN.burn(CHM_TOKEN.balanceOf(address(this)) - chmSold);
        }
        TEAM_VESTING.startVesting();
        MARKETING_VESTING.startVesting();
        startVesting();
        // Transfer all raised funds to treasury
        uint256 etherBalance = WETH_TOKEN.balanceOf(address(this));
        if (etherBalance > 0) {
            WETH_TOKEN.safeTransfer(TREASURY, etherBalance);
        }
        uint256 usdtBalance = USDT_TOKEN.balanceOf(address(this));
        if (usdtBalance > 0) {
            USDT_TOKEN.safeTransfer(TREASURY, usdtBalance);
        }
        uint256 usdcBalance = USDC_TOKEN.balanceOf(address(this));
        if (usdcBalance > 0) {
            USDC_TOKEN.safeTransfer(TREASURY, usdcBalance);
        }
        emit IcoSucceeded();
    }

    function _icoFailed() internal {
        icoState = IcoState.Failed;
        CHM_TOKEN.burn(CHM_TOKEN.balanceOf(address(this)));
        emit IcoFailed();
    }

    function _progressStage() internal {
        if (icoState == IcoState.NotStarted) {
            revert InvalidIcoState(icoState);
        }
        if (icoState == IcoState.Stage11) {
            _endIco();
            return;
        }
        uint256 tokensAvailable = stages[uint256(icoState)].tokensAvailable;
        uint256 newState = uint256(icoState) + 1;
        if (tokensAvailable > 0) {
            stages[newState].tokensAvailable += tokensAvailable;
        }
        stages[newState].startTime = block.timestamp;
        icoState = IcoState(newState);

        emit ProgressedStage(icoState);
    }

    // External function to refund ETH to a buyer
    function refundEth(address refundee) external nonReentrant {
        // Checks
        User memory user = userVesting[refundee];
        if (user.ethOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.ethOwed;
        userVesting[refundee].ethOwed = 0;

        // Interactions
        WETH_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.ETH);
    }

    // External function to refund USDT to a buyer
    function refundUdst(address refundee) external nonReentrant {
        // Checks
        User memory user = userVesting[refundee];
        if (user.usdtOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.usdtOwed;
        userVesting[refundee].usdtOwed = 0;

        // Interactions
        USDT_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.USDT);
    }

    // External function to refund USDC to a buyer
    function refundUsdc(address refundee) external nonReentrant {
        // Checks
        User memory user = userVesting[refundee];
        if (user.usdcOwed <= 0) {
            revert NoRefundAvailable();
        }

        // Effects
        uint128 amount = user.usdcOwed;
        userVesting[refundee].usdcOwed = 0;

        // Interactions
        USDC_TOKEN.approve(refundee, amount);
        emit RefundIssued(refundee, amount, Currency.USDC);
    }

    function getIcoState() external view returns (IcoState) {
        return icoState;
    }

    function getStageDetails() external view returns (Stage memory) {
        return stages[uint256(icoState)];
    }
}
