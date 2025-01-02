// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmIco is AccessManaged, ReentrancyGuard {
    error ZeroAddressNotAllowed();
    error InvalidState();
    error InsufficientPayment();
    error UnsupportedCurrency();
    error InsufficientTokensAvailable();
    error TransferFailed();

    event TokensPurchased(address indexed buyer, uint256 amount, Currency currency, uint256 payment);

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

    struct Stage {
        uint256 tokensAvailable; // Total tokens available for sale (no decimals)
        uint256 tokensRemaining; // Total tokens remaining for sale (no decimals)
        uint256 price; // Price of one token in microUSDT (6 decimals)
        uint256 duration; // Duration of the stage using solidity default encoding
        uint256 startTime; // Start time of the stage using solidity default encoding
    }

    struct User {
        uint256 usdtSpent; // Total USDT measured in microUSDT spent by the user (6 decimals)
        uint256 usdcSpent; // Total USDC measured in microUSDC spent by the user (6 decimals)
        uint256 ethSpent; // Total ETH measured in wei spent by the user (18 decimals)
        uint256 chmBought; // Total CHM bought by the user (no decimals)
    }

    Stage[] private stages;

    mapping(address => User) private userData;

    IcoState private icoState;

    uint256 public constant MINIMUM_RAISE = 1_000_000; // 1 million USDT
    uint256 private raisedAmount; // Total amount raised in microUSDT (6 decimals)

    address public constant CHAINLINK_USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
    AggregatorV3Interface private usdtEthPriceFeed;
    uint8 public chainlinkDecimals;

    IERC20 public usdtToken;
    IERC20 public usdcToken;

    constructor(address _accessControlManager, address _usdtToken, address _usdcToken)
        AccessManaged(_accessControlManager)
    {
        if (_usdtToken == address(0) || _usdcToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        usdtToken = IERC20(_usdtToken);
        usdcToken = IERC20(_usdcToken);
        // TODO: Decide how long stages should last
        // TODO: Do some modelling to decide on stage details
        stages.push(Stage(25_000_000, 25_000_000, 3_500, 1 days, block.timestamp));
        stages.push(Stage(35_000_000, 35_000_000, 3_900, 1 days, block.timestamp));
        stages.push(Stage(50_000_000, 50_000_000, 4_400, 1 days, block.timestamp));
        stages.push(Stage(65_000_000, 65_000_000, 4_900, 1 days, block.timestamp));
        stages.push(Stage(80_000_000, 80_000_000, 5_500, 1 days, block.timestamp));
        stages.push(Stage(95_000_000, 95_000_000, 6_200, 1 days, block.timestamp));
        stages.push(Stage(110_000_000, 110_000_000, 6_900, 1 days, block.timestamp));
        stages.push(Stage(115_000_000, 115_000_000, 7_700, 1 days, block.timestamp));
        stages.push(Stage(130_000_000, 130_000_000, 8_500, 1 days, block.timestamp));
        stages.push(Stage(145_000_000, 145_000_000, 9_400, 1 days, block.timestamp));
        stages.push(Stage(150_000_000, 150_000_000, 10_400, 1 days, block.timestamp));
        icoState = IcoState.NotStarted;
        usdtEthPriceFeed = AggregatorV3Interface(CHAINLINK_USDT_ETH_FEED);
        chainlinkDecimals = usdtEthPriceFeed.decimals();
    }

    function startIco() external restricted {
        if (icoState != IcoState.NotStarted) {
            revert InvalidState();
        }
        icoState = IcoState.Stage1;
        stages[0].startTime = block.timestamp;
    }

    function getLatestUsdtEthPrice() public view returns (uint256) {
        (, int256 price,,,) = usdtEthPriceFeed.latestRoundData();
        return uint256(price);
    }

    function purchaseTokens(uint256 expectedTokens, Currency currency, uint256 payment, IcoState expectedState)
        external
        payable
        nonReentrant
    {
        // Checks
        if (icoState != expectedState) {
            revert InvalidState();
        }
        Stage memory currentStage = stages[uint256(icoState)];
        if (currentStage.tokensRemaining < expectedTokens) {
            revert InsufficientTokensAvailable();
        }
        uint256 cost;
        if (currency == Currency.USDT) {
            cost = expectedTokens * currentStage.price;
            if (usdtToken.allowance(msg.sender, address(this)) < cost) {
                revert InsufficientPayment();
            }
            userData[msg.sender].usdtSpent += payment;
        } else if (currency == Currency.USDC) {
            cost = expectedTokens * currentStage.price;
            if (usdcToken.allowance(msg.sender, address(this)) < cost) {
                revert InsufficientPayment();
            }
            userData[msg.sender].usdcSpent += payment;
        } else if (currency == Currency.ETH) {
            cost = expectedTokens * currentStage.price * getLatestUsdtEthPrice() / (10 ** chainlinkDecimals);
            if (msg.value < cost) {
                revert InsufficientPayment();
            }
            userData[msg.sender].ethSpent += payment;
        } else {
            revert UnsupportedCurrency();
        }
        if (payment < cost) {
            revert InsufficientPayment();
        }

        // Effects
        userData[msg.sender].chmBought += expectedTokens;
        currentStage.tokensRemaining -= expectedTokens;
        raisedAmount += expectedTokens * currentStage.price;

        if (currentStage.tokensRemaining == 0 || block.timestamp >= currentStage.startTime + currentStage.duration) {
            _progressStage();
        }

        // Interactions
        uint256 ethToRefund = 0;
        if (currency == Currency.USDT) {
            usdtToken.safeTransferFrom(msg.sender, address(this), payment);
            ethToRefund = msg.value;
        } else if (currency == Currency.USDC) {
            usdcToken.safeTransferFrom(msg.sender, address(this), payment);
            ethToRefund = msg.value;
        } else if (currency == Currency.ETH) {
            ethToRefund = msg.value - cost;
        }
        if (ethToRefund > 0) {
            payable(msg.sender).transfer(ethToRefund);
        }

        emit TokensPurchased(msg.sender, expectedTokens, currency, payment);
    }

    function progressStage() external nonReentrant restricted {
        _progressStage();
    }

    function _progressStage() internal {
        icoState = IcoState(uint256(icoState) + 1);
        stages[uint256(icoState)].startTime = block.timestamp;
    }

    function refund() external nonReentrant {
        if (icoState != IcoState.Failed) {
            revert InvalidState();
        }
        // Additional refund logic
        // Finalize refund
    }
}
