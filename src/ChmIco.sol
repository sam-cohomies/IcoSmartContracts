// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChmPublicVesting} from "./ChmPublicVesting.sol";
import {User} from "./utils/Structs.sol";

using SafeERC20 for IERC20;

/// @custom:security-contact sam@cohomies.io
contract ChmIco is AccessManaged, ReentrancyGuard {
    error ZeroAddressNotAllowed();
    error InvalidIcoState(IcoState state);
    error InsufficientPayment();
    error UnsupportedCurrency();
    error InsufficientTokensAvailable();
    error TransferFailed();
    error NoRefundAvailable();

    event TokensPurchased(address indexed buyer, uint256 amount, Currency currency, uint256 payment);
    event IcoSucceeded();
    event IcoFailed();
    event ProgressedStage(IcoState newState);
    event RefundIssued(address indexed buyer, uint256 amount, Currency currency);
    event RefundFailed(address indexed buyer, uint256 amount, Currency currency);

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
        uint256 tokensAvailable; // Total tokens currently available for sale (no decimals)
        uint256 price; // Price of one token in microUSDT (6 decimals)
        uint256 duration; // Duration of the stage using solidity default encoding
        uint256 startTime; // Start time of the stage using solidity default encoding
    }

    Stage[] private stages;

    address[] private users;
    mapping(address => User) private userData;

    IcoState private icoState;

    uint256 public constant MINIMUM_RAISE = 1_000_000; // 1 million USDT
    uint256 private raisedAmount; // Total amount raised in microUSDT (6 decimals)
    uint256 private chmSold; // Total CHM sold (no decimals)

    address public constant CHAINLINK_USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
    AggregatorV3Interface private usdtEthPriceFeed;
    uint8 public chainlinkDecimals;

    IERC20 public usdtToken;
    IERC20 public usdcToken;

    address private immutable TREASURY;
    ChmPublicVesting public immutable VESTING_CONTRACT;

    constructor(
        address _accessControlManager,
        address _usdtToken,
        address _usdcToken,
        address _treasury,
        ChmPublicVesting _vestingContract
    ) AccessManaged(_accessControlManager) {
        if (_usdtToken == address(0) || _usdcToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        usdtToken = IERC20(_usdtToken);
        usdcToken = IERC20(_usdcToken);
        TREASURY = _treasury;
        VESTING_CONTRACT = _vestingContract;
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

    function purchaseTokens(uint256 expectedTokens, Currency currency, uint256 payment, IcoState expectedState)
        external
        payable
        nonReentrant
        icoActive
    {
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
        if (userData[msg.sender].chmOwed == 0) {
            userData[msg.sender].index = users.length;
            users.push(msg.sender);
        }
        userData[msg.sender].chmOwed += expectedTokens;
        currentStage.tokensAvailable -= expectedTokens;
        raisedAmount += expectedTokens * currentStage.price;
        chmSold += expectedTokens;

        if (currentStage.tokensAvailable == 0 || block.timestamp >= currentStage.startTime + currentStage.duration) {
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

    function _icoSucceeded() internal {
        icoState = IcoState.Succeeded;
        // Inform vesting contract
        uint256 usersLength = users.length;
        User[] memory usersData = new User[](usersLength);
        for (uint256 i = 0; i < usersLength; i++) {
            usersData[i] = userData[users[i]];
        }
        VESTING_CONTRACT.beginVesting(users, usersData, chmSold);
        // Transfer all raised funds to treasury
        uint256 etherBalance = address(this).balance;
        if (etherBalance > 0) {
            (bool success,) = TREASURY.call{value: etherBalance}("");
            if (!success) {
                revert TransferFailed();
            }
        }
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            usdtToken.safeTransfer(TREASURY, usdtBalance);
        }
        uint256 usdcBalance = usdcToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            usdcToken.safeTransfer(TREASURY, usdcBalance);
        }
        emit IcoSucceeded();
    }

    function _icoFailed() internal {
        icoState = IcoState.Failed;
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

    function refund() external nonReentrant {
        if (icoState != IcoState.Failed) {
            revert InvalidIcoState(icoState);
        }

        User memory user = userData[msg.sender];
        if (user.chmOwed == 0) {
            revert NoRefundAvailable();
        }

        // Process each currency separately to ensure refunds are processed even if one fails
        uint256 usdtRefundRemaining = _refundUdst(msg.sender, user.usdtSpent);
        uint256 usdcRefundRemaining = _refundUsdc(msg.sender, user.usdcSpent);
        uint256 ethRefundRemaining = _refundEth(payable(msg.sender), user.ethSpent);
        uint256 chmOwedRemaining = usdtRefundRemaining + usdcRefundRemaining + ethRefundRemaining;
        if (chmOwedRemaining > 0) {
            chmOwedRemaining = user.chmOwed;
        }

        if (chmOwedRemaining > 0) {
            userData[msg.sender] =
                User(usdtRefundRemaining, usdcRefundRemaining, ethRefundRemaining, chmOwedRemaining, user.index);
        } else {
            address lastUser = users[users.length - 1];
            userData[lastUser].index = user.index;
            users[user.index] = lastUser;
            users.pop();
            delete userData[msg.sender];
        }
    }

    // Internal function to refund USDT to a buyer
    // Returns the amount of USDT that could not be refunded
    function _refundUdst(address buyer, uint256 amount) internal returns (uint256) {
        if (amount > 0) {
            (bool success, bytes memory data) =
                address(usdtToken).call(abi.encodeWithSelector(usdtToken.transfer.selector, buyer, amount));

            if (success && (data.length == 0 || abi.decode(data, (bool)))) {
                emit RefundIssued(buyer, amount, Currency.USDT);
                return 0;
            }

            emit RefundFailed(buyer, amount, Currency.USDT);
            return amount;
        }
        return 0;
    }

    // Internal function to refund USDC to a buyer
    // Returns the amount of USDC that could not be refunded
    function _refundUsdc(address buyer, uint256 amount) internal returns (uint256) {
        if (amount > 0) {
            (bool success, bytes memory data) =
                address(usdcToken).call(abi.encodeWithSelector(usdcToken.transfer.selector, buyer, amount));

            if (success && (data.length == 0 || abi.decode(data, (bool)))) {
                emit RefundIssued(buyer, amount, Currency.USDC);
                return 0;
            }

            emit RefundFailed(buyer, amount, Currency.USDC);
            return amount;
        }
        return 0;
    }

    // Internal function to refund ETH to a buyer
    // Returns the amount of ETH that could not be refunded
    function _refundEth(address payable buyer, uint256 amount) internal returns (uint256) {
        if (amount > 0) {
            (bool success,) = buyer.call{value: amount}("");
            if (success) {
                emit RefundIssued(buyer, amount, Currency.ETH);
                return 0;
            }
            emit RefundFailed(buyer, amount, Currency.ETH);
            return amount;
        }
    }

    function getIcoState() external view returns (IcoState) {
        return icoState;
    }

    function getStageDetails() external view returns (Stage memory) {
        return stages[uint256(icoState)];
    }
}
